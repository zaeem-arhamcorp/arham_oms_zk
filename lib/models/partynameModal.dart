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
      this.lastOrderDays});

  String accCd;
  String accName;
  String accAddress;
  String? add1;
  String? add2;
  String? add3;
  String? city;
  String? zone;
  String mobile;
  String accCartItem;
  String? whNo;
  String? person_nm;
  String? pincode;
  dynamic lat;
  dynamic long;
  num? groupCD;
  num? clBAL;
  double? distanceInMeters;
  int? lastOrderDays;

  factory DatumPartyname.fromJson(Map<String, dynamic> json) => DatumPartyname(
      accCd: json["ACC_CD"] ?? "",
      accName: json["ACC_NAME"] ?? "",
      add1: json["ADD1"] ?? "",
      add2: json["ADD2"] ?? "",
      add3: json["ADD3"] ?? "",
      city: json["CITY"] ?? "",
      zone: json["ZONE"] ?? "",
      accAddress: json["ACC_ADD"] ?? "",
      mobile: json['MOBILE1'] ?? "",
      accCartItem: json['ACC_CART_ITEM'] ?? "",
      whNo: json['WA_NO'] ?? "",
      person_nm: json['PERSON_NM'],
      pincode: json['PINCODE'] ?? "",
      lat: json['LAT'],
      long: json['LONG'],
      groupCD: json['GROUP_CD'] ?? 0,
      clBAL: json['CL_BAL'] ?? 0,
      distanceInMeters: null,
      lastOrderDays: json['LAST_ORDER_DAYS_AGO'] ?? 0);

  Map<String, dynamic> toJson() => {
        "ACC_CD": accCd,
        "ACC_NAME": accName,
        "ACC_ADD": accAddress,
        "Mobile1": mobile,
        "ACC_CART_ITEM": accCartItem,
        "whNo": whNo,
        "ADD1": add1,
        "ADD2": add2,
        "ADD3": add3,
        "CITY": city,
        "ZONE": zone,
        "PERSON_NM": person_nm,
        "PINCODE": pincode,
        "LAT": lat,
        "LONG": long,
        "GROUP_CD": groupCD,
        "CL_BAL": clBAL,
        "distanceInMeters": distanceInMeters,
      };
}
