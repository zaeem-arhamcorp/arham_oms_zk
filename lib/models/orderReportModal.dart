// To parse this JSON data, do
//
//     final orderReportModal = orderReportModalFromJson(jsonString);

import 'dart:convert';

OrderReportModal orderReportModalFromJson(String str) =>
    OrderReportModal.fromJson(json.decode(str));

String orderReportModalToJson(OrderReportModal data) =>
    json.encode(data.toJson());

class OrderReportModal {
  OrderReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumOrder> data;

  factory OrderReportModal.fromJson(Map<String, dynamic> json) =>
      OrderReportModal(
        message: json["message"],
        data: List<DatumOrder>.from(
            json["data"].map((x) => DatumOrder.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumOrder {
  DatumOrder(
      {required this.partyCd,
      required this.oId,
      this.billNo,
      this.billDt,
      required this.netAmt,
      required this.orderAmt,
      required this.orderNo,
      required this.account,
      required this.user,
      required this.ordritms,
      this.narration,
      this.vouchDt,
      this.imgUrl,
      this.remark});

  String partyCd;
  dynamic oId;
  dynamic billNo;
  dynamic billDt;
  dynamic netAmt;
  dynamic orderAmt;
  String? orderNo;
  dynamic vouchDt;
  dynamic narration;
  dynamic imgUrl;
  dynamic remark;
  Account account;
  User user;
  List<Ordritm> ordritms;

  factory DatumOrder.fromJson(Map<String, dynamic> json) => DatumOrder(
        partyCd: json["PARTY_CD"] ?? "",
        billNo: json["BILL_NO"] ?? "",
        oId: json['oId'],
        billDt: json["BILL_DT"] ?? "",
        netAmt: json["NET_AMT"] ?? "",
        orderAmt: json["OR_AMT"] ?? "",
        orderNo: json["ORDER_NO"] ?? "",
        vouchDt: json['VOUCH_DT'] ?? "",
        narration: json['NARRATION'] ?? "",
        imgUrl: json['IMG_URL'] ?? "",
        remark: json['REMARK'] ?? "",
        account: Account.fromJson(json["account"]),
        user: User.fromJson(json['usermast']),
        ordritms: List<Ordritm>.from(
            json["ordritms"].map((x) => Ordritm.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "oId": oId,
        "PARTY_CD": partyCd,
        "BILL_NO": billNo,
        "BILL_DT": billDt,
        "NET_AMT": netAmt,
        "OR_AMT": orderAmt,
        "ORDER_NO": orderNo,
        "VOUCH_DT": vouchDt,
        "NARRATION": narration,
        "IMG_URL": imgUrl,
        "REMARK": remark,
        "account": account.toJson(),
        "usermast": user.toJson(),
        "ordritms": List<dynamic>.from(ordritms.map((x) => x.toJson())),
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

class User {
  User({
    required this.userCd,
    required this.userName,
  });

  String userCd;
  String userName;

  factory User.fromJson(Map<String, dynamic> json) => User(
        userCd: json["USER_CD"],
        userName: json["USER_NAME"],
      );

  Map<String, dynamic> toJson() => {
        "USER_CD": userCd,
        "USER_NAME": userName,
      };
}

class Ordritm {
  Ordritm({
    required this.odId,
    required this.oId,
    required this.itemSr,
    required this.vouchDt,
    this.vouchTime,
    this.pCd,
    required this.itemCd,
    this.lastEdit,
    required this.quantity,
    required this.rate,
    required this.lRate,
    required this.syncId,
    required this.amount,
    this.otherDesc,
    this.fld5,
    required this.item,
  });

  int odId;
  dynamic oId;
  dynamic itemSr;
  dynamic vouchDt;
  dynamic vouchTime;
  dynamic pCd;
  String itemCd;
  dynamic lastEdit;
  dynamic quantity;
  dynamic rate;
  dynamic lRate;
  dynamic syncId;
  dynamic fld5;
  dynamic amount;
  dynamic otherDesc;
  Item item;

  factory Ordritm.fromJson(Map<String, dynamic> json) => Ordritm(
        odId: json["odId"],
        oId: json["oId"],
        itemSr: json["ITEM_SR"],
        vouchDt: json["VOUCH_DT"],
        vouchTime: json["VOUCH_TIME"],
        pCd: json["P_CD"],
        itemCd: json["ITEM_CD"],
        lastEdit: json["LAST_EDIT"],
        quantity: json["QUANTITY"],
        rate: json["RATE"],
        lRate: json['LRATE'] ?? '',
        syncId: json["SYNC_ID"],
        amount: json["AMOUNT"],
        otherDesc: json["OTHER_DESC"],
        fld5: json['FLD5'] ?? '',
        item: Item.fromJson(json["item"]),
      );

  Map<String, dynamic> toJson() => {
        "odId": odId,
        "oId": oId,
        "ITEM_SR": itemSr,
        "VOUCH_DT":
            "${vouchDt.year.toString().padLeft(4, '0')}-${vouchDt.month.toString().padLeft(2, '0')}-${vouchDt.day.toString().padLeft(2, '0')}",
        "VOUCH_TIME": vouchTime,
        "P_CD": pCd,
        "ITEM_CD": itemCd,
        "LAST_EDIT": lastEdit,
        "QUANTITY": quantity,
        "RATE": rate,
        "LRATE": lRate,
        "SYNC_ID": syncId,
        "AMOUNT": amount,
        "OTHER_DESC": otherDesc,
        "FLD5": fld5,
        "item": item.toJson(),
      };
}

class Item {
  Item(
      {required this.itemCd,
      required this.itemName,
      required this.itemSname,
      required this.itemLname,
      required this.deptCd,
      required this.srate1,
      required this.sdisc,
      required this.cStk,
      required this.lastSize});

  String itemCd;
  String itemName;
  String itemSname;
  String itemLname;
  String deptCd;
  dynamic srate1;
  dynamic sdisc;
  dynamic cStk;
  dynamic lastSize;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        itemCd: json["ITEM_CD"],
        itemName: json["ITEM_NAME"],
        itemSname: json["ITEM_SNAME"],
        itemLname: json["ITEM_LNAME"],
        deptCd: json["DEPT_CD"] ?? '',
        srate1: json["SRATE1"],
        sdisc: json["SDISC"],
        cStk: json["C_STK"],
        lastSize: json['LAST_SIZE'],
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "ITEM_NAME": itemName,
        "ITEM_SNAME": itemSname,
        "ITEM_LNAME": itemLname,
        "DEPT_CD": deptCd,
        "SRATE1": srate1,
        "SDISC": sdisc,
        "C_STK": cStk,
        "LAST_SIZE": lastSize
      };
}
