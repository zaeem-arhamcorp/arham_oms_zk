class ProductResponse {
  final String message;
  final List<ProductItem> data;

  ProductResponse({required this.message, required this.data});

  factory ProductResponse.fromJson(Map<String, dynamic> json) {
    return ProductResponse(
      message: json['message']?.toString() ?? "", // Handle null safety
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => ProductItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ProductItem {
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
  final Department deptment;
  final List<String> itemImages;

  ProductItem({
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

  // Override toString to provide readable output
  @override
  String toString() {
    return 'ProductItem(itemCd: $itemCd, itemName: $itemName, deptCd: $deptCd, itemBrand: $itemBrand, itemDesc: $itemDesc)';
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

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
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
      deptment: Department.fromJson(json['deptment'] ?? {}),
      itemImages: List<String>.from(json['item_image']?['ITEM_IMG'] ?? []),
    );
  }
}

class Department {
  final String deptCd;
  final String deptName;
  final String? grouping;
  final String syncId;
  final String? updatedAt;
  final String? createdAt;

  Department({
    required this.deptCd,
    required this.deptName,
    this.grouping,
    required this.syncId,
    this.updatedAt,
    this.createdAt,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
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
