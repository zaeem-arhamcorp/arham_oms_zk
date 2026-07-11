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
    this.totalOrderAmount,
    this.totalBillAmount,
  });

  String message;
  List<DatumOrder> data;
  double? totalOrderAmount;
  double? totalBillAmount;

  factory OrderReportModal.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>?;
    return OrderReportModal(
      message: json["message"],
      data: List<DatumOrder>.from(
          json["data"].map((x) => DatumOrder.fromJson(x))),
      totalOrderAmount: double.tryParse(
          payload?['TOTAL_ORDER_AMOUNT']?.toString() ?? ''),
      totalBillAmount: double.tryParse(
          payload?['TOTAL_BILL_AMOUNT']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        if (totalOrderAmount != null)
          "payload": {
            "TOTAL_ORDER_AMOUNT": totalOrderAmount,
            "TOTAL_BILL_AMOUNT": totalBillAmount,
          },
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
      this.remark,
      this.canEdit,
      this.stockistCd});

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
  dynamic canEdit; // CAN_EDIT flag from API
  Account account;
  User user;
  List<Ordritm> ordritms;
  String? stockistCd;

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
        canEdit: json['CAN_EDIT'] ?? true, // Default to true if not provided
        account: Account.fromJson(json["account"]),
        // user: User.fromJson(json['usermast']),
        user: json["usermast"] != null
            ? User.fromJson(json["usermast"])
            : User(userCd: '', userName: ''),
        ordritms: List<Ordritm>.from(
            json["ordritms"].map((x) => Ordritm.fromJson(x))),
        stockistCd:
            json['STOCKIST_CD']?.toString() ?? json['stockist_cd']?.toString(),
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
        "CAN_EDIT": canEdit,
        "account": account.toJson(),
        "usermast": user.toJson(),
        "ordritms": List<dynamic>.from(ordritms.map((x) => x.toJson())),
        "STOCKIST_CD": stockistCd,
      };
}

class Account {
  Account({
    required this.accName,
    required this.accCd,
    required this.accCity,
    required this.accZone,
  });

  String accName;
  String accCd;
  String accCity;
  String accZone;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        accName: json["ACC_NAME"],
        accCd: json["ACC_CD"],
        accCity: json["CITY"],
        accZone: json["ZONE"],
      );

  Map<String, dynamic> toJson() => {
        "ACC_NAME": accName,
        "ACC_CD": accCd,
        "CITY": accCity,
        "ZONE": accZone,
      };
}

class User {
  User({
    required this.userCd,
    required this.userName,
    this.phone,
  });

  String userCd;
  String userName;
  String? phone;

  factory User.fromJson(Map<String, dynamic> json) => User(
        userCd: json["USER_CD"],
        userName: json["USER_NAME"],
        phone: null, // Phone not available in order API response
      );

  Map<String, dynamic> toJson() => {
        "USER_CD": userCd,
        "USER_NAME": userName,
        "MOBILENO": phone,
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
    this.nRate,
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
  dynamic nRate;
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
        nRate: json["NRATE"],
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
        "VOUCH_DT": vouchDt is DateTime
            ? "${(vouchDt as DateTime).year.toString().padLeft(4, '0')}-${(vouchDt as DateTime).month.toString().padLeft(2, '0')}-${(vouchDt as DateTime).day.toString().padLeft(2, '0')}"
            : (vouchDt ?? ''),
        "VOUCH_TIME": vouchTime,
        "P_CD": pCd,
        "ITEM_CD": itemCd,
        "LAST_EDIT": lastEdit,
        "QUANTITY": quantity,
        "RATE": rate,
        "NRATE": nRate,
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
