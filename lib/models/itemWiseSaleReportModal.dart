// To parse this JSON data, do
//
//     final itemWiseSaleReportModal = itemWiseSaleReportModalFromJson(jsonString);

import 'dart:convert';

ItemWiseSaleReportModal itemWiseSaleReportModalFromJson(String str) =>
    ItemWiseSaleReportModal.fromJson(json.decode(str));

String itemWiseSaleReportModalToJson(ItemWiseSaleReportModal data) =>
    json.encode(data.toJson());

class ItemWiseSaleReportModal {
  ItemWiseSaleReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemWiseSale> data;

  factory ItemWiseSaleReportModal.fromJson(Map<String, dynamic> json) =>
      ItemWiseSaleReportModal(
        message: json["message"],
        data: List<DatumItemWiseSale>.from(
            json["data"].map((x) => DatumItemWiseSale.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumItemWiseSale {
  DatumItemWiseSale({
    required this.vouchDt,
    required this.bookCd,
    required this.itemCd,
    required this.quantity,
    required this.rate,
    required this.vouchAmt,
    required this.item,
    required this.account,
  });

  dynamic vouchDt;
  String bookCd;
  String itemCd;
  dynamic quantity;
  dynamic rate;
  dynamic vouchAmt;
  Item item;
  Account account;

  factory DatumItemWiseSale.fromJson(Map<String, dynamic> json) =>
      DatumItemWiseSale(
        vouchDt: json["VOUCH_DT"],
        bookCd: json["BOOK_CD"],
        itemCd: json["ITEM_CD"],
        quantity: json["QUANTITY"],
        rate: json["RATE"],
        vouchAmt: json["VOUCH_AMT"],
        item: Item.fromJson(json["item"]),
        account: Account.fromJson(json["account"]),
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "ITEM_CD": itemCd,
        "QUANTITY": quantity,
        "RATE": rate,
        "VOUCH_AMT": vouchAmt,
        "item": item.toJson(),
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
