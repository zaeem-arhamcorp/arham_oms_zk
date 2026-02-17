import 'dart:convert';

PartyWiseOutstandingReportModal PartyWiseOutstandingReportModalFromJson(
        String str) =>
    PartyWiseOutstandingReportModal.fromJson(json.decode(str));

String OutstandingReportModalToJson(PartyWiseOutstandingReportModal data) =>
    json.encode(data.toJson());

class PartyWiseOutstandingReportModal {
  PartyWiseOutstandingReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumPartyWiseOutstandingSale> data;

  factory PartyWiseOutstandingReportModal.fromJson(Map<String, dynamic> json) =>
      PartyWiseOutstandingReportModal(
        message: json["message"],
        data: List<DatumPartyWiseOutstandingSale>.from(
            json["data"].map((x) => DatumPartyWiseOutstandingSale.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumPartyWiseOutstandingSale {
  DatumPartyWiseOutstandingSale({
    required this.vouchType,
    required this.vouchNo,
    required this.vouchDt,
    required this.bookCd,
    required this.partyBl,
    required this.partyCd,
    required this.vouchAmt,
    required this.paidAmt,
    required this.osAmt,
    required this.narration,
    required this.syncId,
    required this.dueDate,
    required this.account,
  });

  dynamic vouchType;
  dynamic vouchNo;
  String vouchDt;
  String bookCd;
  dynamic partyBl;
  dynamic partyCd;
  dynamic vouchAmt;
  dynamic paidAmt;
  dynamic osAmt;
  dynamic narration;
  dynamic syncId;
  String dueDate;
  Account account;

  factory DatumPartyWiseOutstandingSale.fromJson(Map<String, dynamic> json) =>
      DatumPartyWiseOutstandingSale(
          vouchType: json['VOUCH_TYPE'],
          vouchNo: json['VOUCH_NO'],
          vouchDt: json["VOUCH_DT"],
          bookCd: json["BOOK_CD"],
          partyBl: json["PARTY_BL"],
          partyCd: json["PARTY_CD"],
          vouchAmt: json["VOUCH_AMT"],
          paidAmt: json["PAID_AMT"],
          osAmt: json['OS_AMT'],
          narration: json['NARRATION'],
          syncId: json['SYNC_ID'],
          dueDate: json['DUE_DATE'],
          account: Account.fromJson(json['account']));

  Map<String, dynamic> toJson() => {
        "VOUCH_TYPE": vouchType,
        "VOUCH_NO": vouchNo,
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "PARTY_BL": partyBl,
        "PARTY_CD": partyCd,
        "VOUCH_AMT": vouchAmt,
        "PAID_AMT": paidAmt,
        "OS_AMT": osAmt,
        "NARRATION": narration,
        "SYNC_ID": syncId,
        "DUE_DATE": dueDate,
        "account": account
      };

  @override
  String toString() {
    return toJson().toString(); // Convert the object to JSON for display
  }
}

class Account {
  Account({
    required this.accName,
    required this.accCd,
  });

  String accName;
  String accCd;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        accName: json["ACC_NAME"],
        accCd: json["ACC_CD"],
      );

  Map<String, dynamic> toJson() => {
        "ACC_NAME": accName,
        "ACC_CD": accCd,
      };

  @override
  String toString() {
    return toJson().toString(); // Convert the object to JSON for display
  }
}
