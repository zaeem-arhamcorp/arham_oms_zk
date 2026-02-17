import 'dart:convert';

ItemWiseReportModal itemWiseReportModalFromJson(String str) =>
    ItemWiseReportModal.fromJson(json.decode(str));

String itemWiseReportModalToJson(ItemWiseReportModal data) =>
    json.encode(data.toJson());

ItemWiseDetailReportModal itemWiseDetailReportModalFromJson(String str) =>
    ItemWiseDetailReportModal.fromJson(json.decode(str));

String itemWiseDetailReportModalToJson(ItemWiseDetailReportModal data) =>
    json.encode(data.toJson());

class ItemWiseReportModal {
  ItemWiseReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemWiseReport> data;

  factory ItemWiseReportModal.fromJson(Map<String, dynamic> json) =>
      ItemWiseReportModal(
        message: json["message"],
        data: List<DatumItemWiseReport>.from(
            json["data"].map((x) => DatumItemWiseReport.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class ItemWiseDetailReportModal {
  ItemWiseDetailReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemWiseDetailReport> data;

  factory ItemWiseDetailReportModal.fromJson(Map<String, dynamic> json) =>
      ItemWiseDetailReportModal(
        message: json["message"],
        data: List<DatumItemWiseDetailReport>.from(
            json["data"].map((x) => DatumItemWiseDetailReport.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumItemWiseDetailReport {
  DatumItemWiseDetailReport({
    required this.itemCd,
    required this.refNo,
    required this.vouchDt,
    required this.sizeCd,
    required this.qty,
    required this.otherDesc,
    required this.rate,
    required this.vouchAmt,
    required this.syncId,
    required this.account,
    required this.item,
  });

  String itemCd;
  dynamic refNo;
  dynamic vouchDt;
  dynamic sizeCd;
  dynamic qty;
  dynamic otherDesc;
  dynamic rate;
  dynamic vouchAmt;
  dynamic syncId;
  Item item;
  Account account;

  factory DatumItemWiseDetailReport.fromJson(Map<String, dynamic> json) =>
      DatumItemWiseDetailReport(
        itemCd: json["ITEM_CD"],
        refNo: json['REF_NO'],
        vouchDt: json['VOUCH_DT'],
        sizeCd: json['SIZE_CD'],
        qty: json['QUANTITY'],
        otherDesc: json['OTHER_DESC'],
        rate: json['RATE'],
        vouchAmt: json['VOUCH_AMT'],
        syncId: json['SYNC_ID'],
        account: Account.fromJson(json['account']),
        item: Item.fromJson(json["item"]),
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "REF_NO": refNo,
        'VOUCH_DT': vouchDt,
        "SIZE_CD": sizeCd,
        "QUANTITY": qty,
        "OTHER_DESC": otherDesc,
        "RATE": rate,
        "VOUCH_AMT": vouchAmt,
        "SYNC_ID": syncId,
        "account": account,
        "item": item,
      };
}

class DatumItemWiseReport {
  DatumItemWiseReport(
      {required this.itemCd,
      required this.sumVouchAmt,
      required this.sumQty,
      required this.item,
      required this.sumOtherDesc});

  String itemCd;
  dynamic sumVouchAmt;
  dynamic sumQty;
  Item item;
  dynamic sumOtherDesc;

  factory DatumItemWiseReport.fromJson(Map<String, dynamic> json) =>
      DatumItemWiseReport(
        itemCd: json["ITEM_CD"],
        sumVouchAmt: json["SUM_VOUCH_AMT"],
        sumQty: json["SUM_QUANTITY"],
        sumOtherDesc: json['SUM_OTHER_DESC'],
        item: Item.fromJson(json["item"]),
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "SUM_VOUCH_AMT": sumVouchAmt,
        "SUM_QUANTITY": sumQty,
        "SUM_OTHER_DESC": sumOtherDesc,
        "item": item,
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
