// To parse this JSON data, do
//
//     final productModal = productModalFromJson(jsonString);

import 'dart:convert';

ProductModal productModalFromJson(String str) =>
    ProductModal.fromJson(json.decode(str));

String productModalToJson(ProductModal data) => json.encode(data.toJson());

InternetDeptmentModal deptmentModalFromJson(String str) =>
    InternetDeptmentModal.fromJson(json.decode(str));

String deptmentModalToJson(DeptmentModal data) => json.encode(data.toJson());

class ProductModal {
  List<DatumProduct> data;
  Payload payload;

  ProductModal({
    required this.data,
    required this.payload,
  });

  factory ProductModal.fromJson(Map<String, dynamic> json) => ProductModal(
        data: List<DatumProduct>.from(
            json["data"].map((x) => DatumProduct.fromJson(x))),
        payload: Payload.fromJson(json["payload"]),
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "payload": payload.toJson(),
      };
}

class InternetDeptmentModal {
  List<DeptmentModal> data;
  String message;

  InternetDeptmentModal({
    required this.data,
    required this.message,
  });

  factory InternetDeptmentModal.fromJson(Map<String, dynamic> json) =>
      InternetDeptmentModal(
        data: List<DeptmentModal>.from(
            json["data"].map((x) => DeptmentModal.fromJson(x))),
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "message": message,
      };
}

class DeptmentModal {
  dynamic DEPT_CD;
  dynamic DEPT_NAME;
  dynamic SYNC_ID;

  DeptmentModal({
    required this.DEPT_CD,
    required this.DEPT_NAME,
    required this.SYNC_ID,
  });

  factory DeptmentModal.fromJson(Map<String, dynamic> json) => DeptmentModal(
      DEPT_CD: json["DEPT_CD"],
      DEPT_NAME: json["DEPT_NAME"],
      SYNC_ID: json["SYNC_ID"]);

  Map<String, dynamic> toJson() => {
        "DEPT_CD": DEPT_CD,
        "DEPT_NAME": DEPT_NAME,
        "SYNC_ID": SYNC_ID,
      };
}

// class ItemImageModal {
//   List<dynamic> itemImg = [];
//   dynamic itemCd;
//   dynamic itemImg1;
//   dynamic itemImg2;
//   dynamic itemImg3;
//   dynamic itemImg4;
//   dynamic itemImg5;
//   dynamic itemImg6;
//   dynamic syncId;
//
//   ItemImageModal(
//       {required this.itemCd,
//       required this.itemImg,
//       required this.itemImg1,
//       required this.itemImg2,
//       required this.itemImg3,
//       required this.itemImg4,
//       required this.itemImg5,
//       required this.itemImg6,
//       required this.syncId});
//
//   factory ItemImageModal.fromJson(Map<String, dynamic> json) => ItemImageModal(
//       itemImg: json["ITEM_IMG"],
//       itemCd: json["ITEM_CD"],
//       itemImg1: json["ITEM_IMG1"],
//       itemImg2: json["ITEM_IMG2"],
//       itemImg3: json["ITEM_IMG3"],
//       itemImg4: json["ITEM_IMG4"],
//       itemImg5: json["ITEM_IMG5"],
//       itemImg6: json["ITEM_IMG6"],
//       syncId: json["SYNC_ID"]);
//
//   Map<String, dynamic> toJson() => {
//         "ITEM_IMG": itemImg,
//         "ITEM_CD": itemCd,
//         "ITEM_IMG1": itemImg1,
//         "ITEM_IMG2": itemImg2,
//         "ITEM_IMG3": itemImg3,
//         "ITEM_IMG4": itemImg4,
//         "ITEM_IMG5": itemImg5,
//         "ITEM_IMG6": itemImg6,
//         "SYNC_ID": syncId,
//       };
// }

class ItemImageModal {
  final List<dynamic> itemImg;
  final String? itemCd;
  final dynamic itemImg1;
  final dynamic itemImg2;
  final dynamic itemImg3;
  final dynamic itemImg4;
  final dynamic itemImg5;
  final dynamic itemImg6;
  final dynamic syncId;

  ItemImageModal({
    required this.itemImg,
    this.itemCd,
    this.itemImg1,
    this.itemImg2,
    this.itemImg3,
    this.itemImg4,
    this.itemImg5,
    this.itemImg6,
    this.syncId,
  });

  factory ItemImageModal.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ItemImageModal(itemImg: []);
    }

    return ItemImageModal(
      itemImg: json["ITEM_IMG"] ?? [],
      itemCd: json["ITEM_CD"],
      itemImg1: json["ITEM_IMG1"],
      itemImg2: json["ITEM_IMG2"],
      itemImg3: json["ITEM_IMG3"],
      itemImg4: json["ITEM_IMG4"],
      itemImg5: json["ITEM_IMG5"],
      itemImg6: json["ITEM_IMG6"],
      syncId: json["SYNC_ID"],
    );
  }

  Map<String, dynamic> toJson() => {
    "ITEM_IMG": itemImg,
    "ITEM_CD": itemCd,
    "ITEM_IMG1": itemImg1,
    "ITEM_IMG2": itemImg2,
    "ITEM_IMG3": itemImg3,
    "ITEM_IMG4": itemImg4,
    "ITEM_IMG5": itemImg5,
    "ITEM_IMG6": itemImg6,
    "SYNC_ID": syncId,
  };
}


class DatumProduct {
  dynamic nrate;
  dynamic prate;
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
  dynamic avlStk;
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
  dynamic pDisc;
  dynamic gstPerc;
  dynamic tLAND;
  final DeptmentModal? deptment;
  ItemImageModal? itemImage;

  DatumProduct(
      {required this.nrate,
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
      required this.deptment,
      this.itemImage,
      this.avlStk,
      this.itemDesc,
      this.itemBrand,
      this.itemCat,
      this.itemCd2,
      this.itemGrade,
      this.rackNo,
      this.subCat,
      this.prate,
      this.pDisc,
      this.gstPerc,
      this.tLAND});

  factory DatumProduct.fromJson(Map<String, dynamic> json) => DatumProduct(
    nrate: json["NRATE"],
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
    avlStk: json['AVL_STK'],
    syncId: json["SYNC_ID"],
    frmlSrt1: json["FRML_SRT1"],
    prate: json['PRATE'],
    sdisc: json["SDISC"],
    sdisc1: json["SDISC1"],
    itemImage: json['item_image'] != null
        ? ItemImageModal.fromJson(json['item_image'])
        : null,
    itemDesc: json['ITEM_DESC'],
    itemCd2: json['ITEM_CD2'],
    itemGrade: json['ITEM_GRADE'],
    rackNo: json['RACK_NO'],
    itemCat: json['ITEM_CAT'],
    subCat: json['SUBCAT'],
    pDisc: json['PDISC'],
    gstPerc: json['GST_PERC'],
    tLAND: json['T_LAND'],
    itemBrand: json['ITEM_BRAND'],
    // Null check for 'deptment'
    deptment: json['deptment'] != null
        ? DeptmentModal.fromJson(json['deptment'])
        : null,
  );

  Map<String, dynamic> toJson() => {
        "NRATE": nrate,
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
        "AVL_STK": avlStk,
        "SYNC_ID": syncId,
        "FRML_SRT1": frmlSrt1,
        "SDISC": sdisc,
        "SDISC1": sdisc1,
        "deptment": deptment,
        "itemImg": itemImage,
        "ITEM_DESC": itemDesc,
        "ITEM_CD2": itemCd2,
        "ITEM_GRADE": itemGrade,
        "RACK_NO": rackNo,
        "ITEM_CAT": itemCat,
        "PDISC": pDisc,
        "GST_PERC": gstPerc,
        "T_LAND": tLAND,
        "SUBCAT": subCat,
        "PRATE": prate,
        "ITEM_BRAND": itemBrand,
      };
}

class Payload {
  Pagination pagination;

  Payload({
    required this.pagination,
  });

  factory Payload.fromJson(Map<String, dynamic> json) => Payload(
        pagination: Pagination.fromJson(json["pagination"]),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination.toJson(),
      };
}

class Pagination {
  dynamic itemsPerPage;
  dynamic page;
  dynamic total;
  dynamic lastPage;
  dynamic from;
  dynamic to;

  Pagination({
    required this.itemsPerPage,
    required this.page,
    required this.total,
    required this.lastPage,
    required this.from,
    required this.to,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        itemsPerPage: json["items_per_page"],
        page: json["page"],
        total: json["total"],
        lastPage: json["last_page"],
        from: json["from"],
        to: json["to"],
      );

  Map<String, dynamic> toJson() => {
        "items_per_page": itemsPerPage,
        "page": page,
        "total": total,
        "last_page": lastPage,
        "from": from,
        "to": to,
      };
}
