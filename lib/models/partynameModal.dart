// To parse this JSON data, do
//
//     final partynameModal = partynameModalFromJson(jsonString);

import 'dart:convert';

PartynameModal partynameModalFromJson(String str) =>
    PartynameModal.fromJson(json.decode(str));

String partynameModalToJson(PartynameModal data) => json.encode(data.toJson());

class PartynameModal {
  PartynameModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumPartyname> data;

  factory PartynameModal.fromJson(Map<String, dynamic> json) => PartynameModal(
        message: json["message"],
        data: List<DatumPartyname>.from(
            json["data"].map((x) => DatumPartyname.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumPartyname {
  DatumPartyname(
      {required this.accCd,
      required this.accName,
      required this.accAddress,
      required this.mobile,
      required this.accCartItem,
      this.beatCd,
      this.city,
      this.add1,
      this.add2,
      this.add3,
      this.zone,
      this.whNo,
      this.person_nm,
      this.pincode,
      this.lat,
      this.long,
      this.groupCD,
      this.clBAL,
      this.distanceInMeters,
      this.lastOrderDays,
      this.state,
      this.gstNo,
      this.gstType,
      this.drugLic1,
      this.drugLic2,
      this.fssaiNo,
      this.email,
      this.panNo,
      this.creditDay,
      this.crLimit});

  String accCd;
  String accName;
  String? beatCd;
  String accAddress;
  String? add1;
  String? add2;
  String? add3;
  String? city;
  String? zone;
  String? state;
  String mobile;
  String accCartItem;
  String? whNo;
  String? person_nm;
  String? pincode;
  String? email;
  String? panNo;
  String? gstNo;
  String? gstType;
  String? drugLic1;
  String? drugLic2;
  String? fssaiNo;
  dynamic lat;
  dynamic long;
  num? groupCD;
  num? clBAL;
  num? creditDay;
  num? crLimit;
  double? distanceInMeters;
  int? lastOrderDays;

  factory DatumPartyname.fromJson(Map<String, dynamic> json) => DatumPartyname(
      accCd: json["ACC_CD"] ?? "",
      accName: json["ACC_NAME"] ?? "",
      beatCd: json["BEAT_CD"] ?? "",
      add1: json["ADD1"] ?? "",
      add2: json["ADD2"] ?? "",
      add3: json["ADD3"] ?? "",
      city: json["CITY"] ?? "",
      zone: json["ZONE"] ?? "",
      state: json["STATE"] ?? "",
      accAddress: json["ACC_ADD"] ?? "",
      mobile: json['MOBILE1'] ?? "",
      accCartItem: json['ACC_CART_ITEM'] ?? "",
      whNo: json['WA_NO'] ?? "",
      person_nm: json['PERSON_NM'],
      pincode: json['PINCODE'] ?? "",
      email: json['EMAIL'] ?? "",
      panNo: json['PAN_NO'] ?? "",
      gstNo: json['GST_NO'] ?? "",
      gstType: json['GST_TYPE'] ?? "",
      drugLic1: json['DRUG_LIC1'] ?? "",
      drugLic2: json['DRUG_LIC2'] ?? "",
      fssaiNo: json['FSSAI_NO'] ?? "",
      lat: json['LAT'],
      long: json['LONG'],
      groupCD: json['GROUP_CD'] ?? 0,
      clBAL: json['CL_BAL'] ?? 0,
      creditDay: json['CREDIT_DAY'],
      crLimit: json['CR_LIMIT'],
      distanceInMeters: null,
      lastOrderDays: json['LAST_ORDER_DAYS_AGO'] ?? 0);

  Map<String, dynamic> toJson() => {
        "ACC_CD": accCd,
        "ACC_NAME": accName,
        "BEAT_CD": beatCd,
        "ACC_ADD": accAddress,
        "Mobile1": mobile,
        "ACC_CART_ITEM": accCartItem,
        "whNo": whNo,
        "ADD1": add1,
        "ADD2": add2,
        "ADD3": add3,
        "CITY": city,
        "ZONE": zone,
        "STATE": state,
        "PERSON_NM": person_nm,
        "PINCODE": pincode,
        "EMAIL": email,
        "PAN_NO": panNo,
        "GST_NO": gstNo,
        "GST_TYPE": gstType,
        "DRUG_LIC1": drugLic1,
        "DRUG_LIC2": drugLic2,
        "FSSAI_NO": fssaiNo,
        "LAT": lat,
        "LONG": long,
        "GROUP_CD": groupCD,
        "CL_BAL": clBAL,
        "CREDIT_DAY": creditDay,
        "CR_LIMIT": crLimit,
        "distanceInMeters": distanceInMeters,
      };
}
