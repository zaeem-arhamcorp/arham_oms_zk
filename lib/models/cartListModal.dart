// To parse this JSON data, do
//
//     final cartListModal = cartListModalFromJson(jsonString);

import 'dart:convert';

import 'package:arham_corporation/models/productModal.dart';

CartListModal cartListModalFromJson(String str) =>
    CartListModal.fromJson(json.decode(str));

String cartListModalToJson(CartListModal data) => json.encode(data.toJson());

class CartListModal {
  CartListModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumCartList> data;

  factory CartListModal.fromJson(Map<String, dynamic> json) => CartListModal(
        message: json["message"],
        data: List<DatumCartList>.from(
            json["data"].map((x) => DatumCartList.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumCartList {
  DatumCartList({
    this.cId,
    this.partyCd,
    this.userCd,
    required this.itemCd,
    this.quantity,
    this.otherDesc,
    this.rate,
    this.lrate,
    this.amount,
    this.syncId,
    this.item,
    this.fld5,
  });

  dynamic cId;
  dynamic partyCd;
  dynamic userCd;
  dynamic itemCd;
  dynamic quantity;
  dynamic rate;
  dynamic lrate;
  dynamic otherDesc;

  //dynamic amount;
  double? amount; // Changed from dynamic to double
  dynamic syncId;
  dynamic fld5;
  DatumProduct? item;

  factory DatumCartList.fromJson(Map<String, dynamic> json) => DatumCartList(
        cId: json["cId"],
        partyCd: json["PARTY_CD"],
        userCd: json["USER_CD"],
        itemCd: json["ITEM_CD"],
        quantity: json["QUANTITY"],
        rate: json["RATE"],
        lrate: json["LRATE"] ?? 0.0,
        // Default to 0.0 if null
        //amount: json["AMOUNT"],
        amount: (json["AMOUNT"] is String)
            ? double.tryParse(json["AMOUNT"]) ?? 0.0
            : json["AMOUNT"]?.toDouble() ?? 0.0,
        // Ensure amount is a double

        syncId: json["SYNC_ID"],
        otherDesc: json["OTHER_DESC"],
        fld5: json['FLD5'],
        item: DatumProduct.fromJson(json["item"]),
      );

  factory DatumCartList.fromLocal(Map<String, dynamic> json) {
    try {
      // Safe value extraction
      final quantity = json['quantity'] ?? 0;
      final rate = json['rate'] ?? 0;
      final lrate = json['lrate'] ?? 0.0;
      final amount = json['amount'] ?? 0;

      // Since DatumProduct requires many fields, provide safe defaults
      return DatumCartList(
        cId: json['id'],
        partyCd: json['party_cd'] ?? '',
        userCd: null,
        itemCd: json['item_cd'] ?? '',
        quantity: quantity,
        rate: rate,
        lrate: (lrate is String)
            ? double.tryParse(lrate) ?? 0.0
            : (lrate as num?)?.toDouble() ?? 0.0,
        amount: (amount is String)
            ? double.tryParse(amount) ?? 0.0
            : (amount as num?)?.toDouble() ?? 0.0,
        syncId: null,
        otherDesc: json['other_desc'] ?? '',
        fld5: json['fld5'] ?? '',
        // Create minimal DatumProduct for offline display
        item: DatumProduct(
          nrate: json['nrate'] ?? 0,
          itemCd: json['item_cd'] ?? 'UNKNOWN',
          itemName: json['item_name'] ?? 'Unknown Product',
          itemSname: 'Unknown',
          itemLname: '',
          deptCd: '',
          srate1: 0,
          srate3: (json['nrate'] != null && json['nrate'] != 0)
              ? json['nrate']
              : (json['rate'] ?? 0),
          cStk: 0,
          syncId: 0,
          frmlSrt1: '',
          sdisc: 0,
          sdisc1: 0,
          deptment: null,
        ),
      );
    } catch (e) {
      print("Fatal error in DatumCartList.fromLocal: $e. Input: $json");
      // Return a safe default instead of crashing
      return DatumCartList(
        cId: null,
        partyCd: '',
        userCd: null,
        itemCd: json['item_cd'] ?? 'ERROR',
        quantity: 0,
        rate: 0,
        lrate: 0,
        amount: 0,
        syncId: null,
        otherDesc: '',
        fld5: '',
        item: DatumProduct(
          nrate: 0,
          itemCd: json['item_cd'] ?? 'ERROR',
          itemName: 'Error: ${e.toString()}',
          itemSname: 'ERROR',
          itemLname: '',
          deptCd: '',
          srate1: 0,
          srate3: 0,
          cStk: 0,
          syncId: 0,
          frmlSrt1: '',
          sdisc: 0,
          sdisc1: 0,
          deptment: null,
        ),
      );
    }
  }

  Map<String, dynamic> toJson() => {
        "cId": cId,
        "PARTY_CD": partyCd,
        "USER_CD": userCd,
        "ITEM_CD": itemCd,
        "QUANTITY": quantity,
        "RATE": rate,
        "LRATE": lrate,
        // If lrate is null, it will stay as null or you can set it to 0.0
        "AMOUNT": amount,
        "SYNC_ID": syncId,
        "OTHER_DESC": otherDesc,
        "FLD5": fld5,
        "item": item == null ? "" : item!.toJson(),
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
  dynamic itemDesc;
  dynamic itemCd2;
  dynamic itemGrade;
  dynamic rackNo;
  dynamic itemCat;
  dynamic subCat;
  dynamic itemBrand;
  DeptmentModal deptment;
  ItemImageModal? itemImage;

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
      required this.sdisc1,
      this.itemImage,
      required this.deptment,
      this.itemDesc,
      this.itemBrand,
      this.itemCat,
      this.itemCd2,
      this.itemGrade,
      this.rackNo,
      this.subCat});

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
      itemDesc: json['ITEM_DESC'],
      itemCd2: json['ITEM_CD2'],
      itemGrade: json['ITEM_GRADE'],
      rackNo: json['RACK_NO'],
      itemCat: json['ITEM_CAT'],
      subCat: json['SUBCAT'],
      itemBrand: json['ITEM_BRAND'],
      itemImage: json['item_image'] != null
          ? ItemImageModal.fromJson(json['item_image'])
          : null,
      deptment: DeptmentModal.fromJson(json['deptment']));

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
        "SDISC1": sdisc1,
        "itemImg": itemImage,
        "deptment": deptment,
        "ITEM_DESC": itemDesc,
        "ITEM_CD2": itemCd2,
        "ITEM_GRADE": itemGrade,
        "RACK_NO": rackNo,
        "ITEM_CAT": itemCat,
        "SUBCAT": subCat,
        "ITEM_BRAND": itemBrand,
      };
}
