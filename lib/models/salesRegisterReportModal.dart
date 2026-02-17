import 'dart:convert';

import 'package:arham_corporation/models/itemLedgerReportModal.dart';

SalesRegisterReportModal salesRegisterReportModalFromJson(String str) =>
    SalesRegisterReportModal.fromJson(json.decode(str));

String salesRegisterReportModalToJson(SalesRegisterReportModal data) =>
    json.encode(data.toJson());

class SalesRegisterReportModal {
  SalesRegisterReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumSalesRegisterReport> data;

  factory SalesRegisterReportModal.fromJson(Map<String, dynamic> json) =>
      SalesRegisterReportModal(
        message: json["message"],
        data: List<DatumSalesRegisterReport>.from(
            json["data"].map((x) => DatumSalesRegisterReport.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumSalesRegisterReport {
  DatumSalesRegisterReport(
      {required this.vouchDt,
      required this.bookCd,
      required this.partyBl,
      required this.partyCd,
      required this.narration,
      required this.vouchType,
      required this.vouchAmt,
      required this.account});

  dynamic vouchDt;
  dynamic bookCd;
  dynamic partyBl;
  dynamic partyCd;
  dynamic narration;
  dynamic vouchType;
  dynamic vouchAmt;
  Account account;

  factory DatumSalesRegisterReport.fromJson(Map<String, dynamic> json) =>
      DatumSalesRegisterReport(
          vouchDt: json["VOUCH_DT"],
          bookCd: json["BOOK_CD"],
          partyBl: json["PARTY_BL"],
          partyCd: json["PARTY_CD"],
          narration: json["NARRATION"],
          vouchType: json["VOUCH_TYPE"],
          vouchAmt: json["VOUCH_AMT"],
          account: Account.fromJson(json['partyAccount']));

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "PARTY_BL": partyBl,
        "PARTY_CD": partyCd,
        "NARRATION": narration,
        "VOUCH_TYPE": vouchType,
        "VOUCH_AMT": vouchAmt,
        "partyAccount": account.toJson()
      };
}
