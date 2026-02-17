// To parse this JSON data, do
//
//     final partyWiseItemWiseSaleReportModal = partyWiseItemWiseSaleReportModalFromJson(jsonString);

import 'dart:convert';

PartyWiseItemWiseSaleReportModal partyWiseItemWiseSaleReportModalFromJson(
        String str) =>
    PartyWiseItemWiseSaleReportModal.fromJson(json.decode(str));

String partyWiseItemWiseSaleReportModalToJson(
        PartyWiseItemWiseSaleReportModal data) =>
    json.encode(data.toJson());

PartyWiseItemWiseSaleDetailReportModal
    partyWiseItemWiseSaleDetailReportModalFromJson(String str) =>
        PartyWiseItemWiseSaleDetailReportModal.fromJson(json.decode(str));

String partyWiseItemWiseSaleDetailReportModalToJson(
        PartyWiseItemWiseSaleDetailReportModal data) =>
    json.encode(data.toJson());

class PartyWiseItemWiseSaleReportModal {
  PartyWiseItemWiseSaleReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemWisePartyWise> data;

  factory PartyWiseItemWiseSaleReportModal.fromJson(
          Map<String, dynamic> json) =>
      PartyWiseItemWiseSaleReportModal(
        message: json["message"],
        data: List<DatumItemWisePartyWise>.from(
            json["data"].map((x) => DatumItemWisePartyWise.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class PartyWiseItemWiseSaleDetailReportModal {
  PartyWiseItemWiseSaleDetailReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumItemWisePartyWiseDetail> data;

  factory PartyWiseItemWiseSaleDetailReportModal.fromJson(
          Map<String, dynamic> json) =>
      PartyWiseItemWiseSaleDetailReportModal(
        message: json["message"],
        data: List<DatumItemWisePartyWiseDetail>.from(
            json["data"].map((x) => DatumItemWisePartyWiseDetail.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumItemWisePartyWise {
  DatumItemWisePartyWise({
    required this.itemCd,
    required this.deptName,
    required this.itemName,
    required this.vouchAmt,
    required this.rate,
    required this.cStk,
    required this.otherDesc,
    required this.qty,
  });

  dynamic itemCd;
  dynamic deptName;
  dynamic itemName;
  dynamic vouchAmt;
  dynamic rate;
  dynamic cStk;
  dynamic otherDesc;
  dynamic qty;

  factory DatumItemWisePartyWise.fromJson(Map<String, dynamic> json) =>
      DatumItemWisePartyWise(
          itemCd: json["ITEM_CD"],
          deptName: json["DEPT_NAME"],
          itemName: json["ITEM_NAME"],
          vouchAmt: json["VOUCH_AMT"] ?? "",
          rate: json["RATE"] ?? "",
          cStk: json["C_STK"] ?? "",
          otherDesc: json['OTHER_DESC'] ?? "",
          qty: json['QUANTITY'] ?? "");

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "DEPT_NAME": deptName,
        "ITEM_NAME": itemName,
        "VOUCH_AMT": vouchAmt,
        "RATE": rate,
        "C_STK": cStk,
        "OTHER_DESC": otherDesc,
        "QUANTITY": qty
      };
}

class DatumItemWisePartyWiseDetail {
  DatumItemWisePartyWiseDetail({
    required this.vouchDt,
    required this.bookCd,
    required this.refNo,
    required this.qty,
    required this.otherDesc,
    required this.rate,
    required this.vouchAmt,
  });

  dynamic vouchDt;
  String bookCd;
  String refNo;
  dynamic qty;
  dynamic otherDesc;
  dynamic rate;
  dynamic vouchAmt;

  factory DatumItemWisePartyWiseDetail.fromJson(Map<String, dynamic> json) =>
      DatumItemWisePartyWiseDetail(
        vouchDt: json["VOUCH_DT"],
        bookCd: json["BOOK_CD"],
        refNo: json["REF_NO"],
        qty: json["QUANTITY"],
        otherDesc: json["OTHER_DESC"],
        rate: json["RATE"],
        vouchAmt: json['VOUCH_AMT'],
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "REF_NO": refNo,
        "QUANTITY": qty,
        "OTHER_DESC": otherDesc,
        "RATE": rate,
        "VOUCH_AMT": vouchAmt,
      };
}
