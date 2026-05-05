// To parse this JSON data, do
//
//     final itemListModal = itemListModalFromJson(jsonString);

import 'dart:convert';

ItemListModal itemListModalFromJson(String str) =>
    ItemListModal.fromJson(json.decode(str));

String itemListModalToJson(ItemListModal data) => json.encode(data.toJson());

class ItemListModal {
  ItemListModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemList> data;

  factory ItemListModal.fromJson(Map<String, dynamic> json) => ItemListModal(
        message: json["message"],
        data: List<DatumItemList>.from(
            json["data"].map((x) => DatumItemList.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumItemList {
  DatumItemList({
    required this.itemCd,
    required this.itemName,
    required this.deptCd,
  });

  String itemCd;
  String itemName;
  String deptCd;

  factory DatumItemList.fromJson(Map<String, dynamic> json) => DatumItemList(
        itemCd: json["ITEM_CD"] ?? '',
        itemName: json["ITEM_NAME"] ?? '',
        deptCd: json["DEPT_CD"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "ITEM_NAME": itemName,
        "DEPT_CD": deptCd,
      };
}
