import 'dart:convert';

PartyWiseReportModal partyWiseReportModalFromJson(String str) =>
    PartyWiseReportModal.fromJson(json.decode(str));

String partyWiseReportModalToJson(PartyWiseReportModal data) =>
    json.encode(data.toJson());

PartyWiseDetailReportModal partyWiseDetailReportModalFromJson(String str) =>
    PartyWiseDetailReportModal.fromJson(json.decode(str));

String partyWiseDetailReportModalToJson(PartyWiseDetailReportModal data) =>
    json.encode(data.toJson());

class PartyWiseReportModal {
  PartyWiseReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumPartyWiseReport> data;

  factory PartyWiseReportModal.fromJson(Map<String, dynamic> json) =>
      PartyWiseReportModal(
        message: json["message"],
        data: List<DatumPartyWiseReport>.from(
            json["data"].map((x) => DatumPartyWiseReport.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class PartyWiseDetailReportModal {
  PartyWiseDetailReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumPartyWiseDetailReport> data;

  factory PartyWiseDetailReportModal.fromJson(Map<String, dynamic> json) =>
      PartyWiseDetailReportModal(
        message: json["message"],
        data: List<DatumPartyWiseDetailReport>.from(
            json["data"].map((x) => DatumPartyWiseDetailReport.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumPartyWiseReport {
  DatumPartyWiseReport(
      {required this.accName, required this.accCd, required this.vouchAmt});

  String accName;
  dynamic accCd;
  dynamic vouchAmt;

  factory DatumPartyWiseReport.fromJson(Map<String, dynamic> json) =>
      DatumPartyWiseReport(
        accName: json["ACC_NAME"],
        accCd: json["ACC_CD"],
        vouchAmt: json["VOUCH_AMT"],
      );

  Map<String, dynamic> toJson() =>
      {"ACC_NAME": accName, "ACC_CD": accCd, "VOUCH_AMT": vouchAmt};
}

class DatumPartyWiseDetailReport {
  DatumPartyWiseDetailReport(
      {required this.vouchDt,
      required this.bookCd,
      required this.partyBl,
      required this.partyCd,
      required this.narration,
      required this.vouchType,
      required this.vouchAmt});

  dynamic vouchDt;
  dynamic bookCd;
  dynamic partyBl;
  dynamic partyCd;
  dynamic narration;
  dynamic vouchType;
  dynamic vouchAmt;

  factory DatumPartyWiseDetailReport.fromJson(Map<String, dynamic> json) =>
      DatumPartyWiseDetailReport(
        vouchDt: json["VOUCH_DT"],
        bookCd: json["BOOK_CD"],
        partyBl: json["PARTY_BL"],
        partyCd: json["PARTY_CD"],
        narration: json["NARRATION"],
        vouchType: json["VOUCH_TYPE"],
        vouchAmt: json["VOUCH_AMT"],
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "PARTY_BL": partyBl,
        "PARTY_CD": partyCd,
        "NARRATION": narration,
        "VOUCH_TYPE": vouchType,
        "VOUCH_AMT": vouchAmt
      };
}
