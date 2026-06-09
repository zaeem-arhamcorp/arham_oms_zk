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
  final String deptCd;
  final String deptName;
  final String? grouping;
  final String syncId;
  final String? updatedAt;
  final String? createdAt;

  DeptmentModal({
    required this.deptCd,
    required this.deptName,
    this.grouping,
    required this.syncId,
    this.updatedAt,
    this.createdAt,
  });

  factory DeptmentModal.fromJson(Map<String, dynamic> json) {
    return DeptmentModal(
      deptCd: json['DEPT_CD']?.toString() ?? "",
      deptName: json['DEPT_NAME']?.toString() ?? "",
      grouping: json['GROUPING']?.toString(),
      syncId: json['SYNC_ID']?.toString() ?? "",
      updatedAt: json['UPDATED_AT']?.toString(),
      createdAt: json['CREATED_AT']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DEPT_CD': deptCd,
      'DEPT_NAME': deptName,
      'GROUPING': grouping,
      'SYNC_ID': syncId,
      'UPDATED_AT': updatedAt,
      'CREATED_AT': createdAt,
    };
  }
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
  final String? itemCd2;
  final String? nrate;
  final String? avlStk;
  final String? exDt;
  final String? rackNo;
  final String? itemCat;
  final String? subCat;
  final String? itemBrand;
  final String itemCd;
  final String itemName;
  final String itemSname;
  final String? itemBoxPacking;
  final String? itemLname;
  final String deptCd;
  final String srate1;
  final String srate3;
  final String syncId;
  final String? itemGrade;
  final String? itemDesc;
  final String prate;
  final String pdisc;
  final String? tLAND;
  final String? gstPerc;
  final String? frmlSrt1;
  final String? sdisc;
  final String? sdisc1;
  final String? cStk;
  final String? orStk;
  final String? minStk;
  final String? hsnNo;
  final DeptmentModal deptment;
  final List<String> itemImages;

  DatumProduct({
    this.itemCd2,
    this.nrate,
    this.avlStk,
    this.exDt,
    this.rackNo,
    this.itemCat,
    this.subCat,
    this.itemBrand,
    required this.itemCd,
    required this.itemName,
    required this.itemSname,
    required this.itemBoxPacking,
    this.itemLname,
    required this.deptCd,
    required this.srate1,
    required this.srate3,
    required this.syncId,
    this.itemGrade,
    this.itemDesc,
    required this.prate,
    required this.pdisc,
    required this.tLAND,
    required this.gstPerc,
    this.frmlSrt1,
    this.sdisc,
    this.sdisc1,
    this.cStk,
    this.orStk,
    this.minStk,
    this.hsnNo,
    required this.deptment,
    required this.itemImages,
  });

  factory DatumProduct.fromJson(Map<String, dynamic> json) {
    return DatumProduct(
      itemCd2: json['ITEM_CD2']?.toString(),
      nrate: json['NRATE']?.toString(),
      avlStk: json['AVL_STK']?.toString(),
      exDt: json['EX_DT']?.toString(),
      rackNo: json['RACK_NO']?.toString(),
      itemCat: json['ITEM_CAT']?.toString() ?? "",
      subCat: json['SUBCAT']?.toString(),
      itemBrand: json['ITEM_BRAND']?.toString(),
      itemCd: json['ITEM_CD']?.toString() ?? "",
      itemName: json['ITEM_NAME']?.toString() ?? "",
      itemSname: json['ITEM_SNAME']?.toString() ?? "",
      itemBoxPacking: json['ITEM_BOX_PACKING']?.toString() ?? "",
      itemLname: json['ITEM_LNAME']?.toString(),
      deptCd: json['DEPT_CD']?.toString() ?? "",
      srate1: json['SRATE1']?.toString() ?? "",
      srate3: json['SRATE3']?.toString() ?? "",
      syncId: json['SYNC_ID']?.toString() ?? "",
      itemGrade: json['ITEM_GRADE']?.toString(),
      itemDesc: json['ITEM_DESC']?.toString(),
      prate: json['PRATE']?.toString() ?? "",
      pdisc: json['PDISC']?.toString() ?? "",
      tLAND: json['T_LAND']?.toString() ?? "",
      gstPerc: json['GST_PERC']?.toString() ?? "",
      frmlSrt1: json['FRML_SRT1']?.toString(),
      sdisc: json['SDISC']?.toString(),
      sdisc1: json['SDISC1']?.toString(),
      cStk: json['C_STK']?.toString(),
      orStk: json['OR_STK']?.toString(),
      minStk: json['MIN_STK']?.toString() ?? "",
      hsnNo: json['HSN_NO']?.toString(),
      deptment: DeptmentModal.fromJson(json['deptment'] ?? {}),
      itemImages: List<String>.from(json['item_image']?['ITEM_IMG'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemCd2': itemCd2,
      'nrate': nrate,
      'avlStk': avlStk,
      'exDt': exDt,
      'rackNo': rackNo,
      'itemCat': itemCat,
      'subCat': subCat,
      'itemBrand': itemBrand,
      'itemCd': itemCd,
      'itemName': itemName,
      'itemSname': itemSname,
      'itemBoxPacking': itemBoxPacking,
      'itemLname': itemLname,
      'deptCd': deptCd,
      'srate1': srate1,
      'srate3': srate3,
      'syncId': syncId,
      'itemGrade': itemGrade,
      'itemDesc': itemDesc,
      'prate': prate,
      'pdisc': pdisc,
      'tLAND': tLAND,
      'gstPerc': gstPerc,
      'frmlSrt1': frmlSrt1,
      'sdisc': sdisc,
      'sdisc1': sdisc1,
      'cStk': cStk,
      'orStk': orStk,
      'minStk': minStk,
      'hsnNo': hsnNo,
      'deptment': deptment.toJson(),
      'itemImages': itemImages,
    };
  }
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
