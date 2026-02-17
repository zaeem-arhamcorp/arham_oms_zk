// To parse this JSON data, do
//
//     final dailReportListModal = dailReportListModalFromJson(jsonString);

import 'dart:convert';

DailReportListModal dailReportListModalFromJson(String str) =>
    DailReportListModal.fromJson(json.decode(str));

String dailReportListModalToJson(DailReportListModal data) =>
    json.encode(data.toJson());

class DailReportListModal {
  DailReportListModal({
    required this.message,
    required this.data,
  });

  String message;
  DataDailyReport data;

  factory DailReportListModal.fromJson(Map<String, dynamic> json) =>
      DailReportListModal(
        message: json["message"],
        data: DataDailyReport.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data.toJson(),
      };
}

class DataDailyReport {
  DataDailyReport({
    required this.party,
    required this.items,
    required this.overview,
  });

  List<PartyDailyReport> party;
  List<ItemdailyReport> items;
  OverviewDailyReport overview;

  factory DataDailyReport.fromJson(Map<String, dynamic> json) =>
      DataDailyReport(
        party: List<PartyDailyReport>.from(
            json["party"].map((x) => PartyDailyReport.fromJson(x))),
        items: List<ItemdailyReport>.from(
            json["items"].map((x) => ItemdailyReport.fromJson(x))),
        overview: OverviewDailyReport.fromJson(json["overview"]),
      );

  Map<String, dynamic> toJson() => {
        "party": List<dynamic>.from(party.map((x) => x.toJson())),
        "items": List<dynamic>.from(items.map((x) => x.toJson())),
        "overview": "",
      };
}

class ItemdailyReport {
  ItemdailyReport({
    required this.itemCd,
    required this.vouchAmt,
    required this.itemName,
  });

  String itemCd;
  dynamic vouchAmt;
  String itemName;

  factory ItemdailyReport.fromJson(Map<String, dynamic> json) =>
      ItemdailyReport(
        itemCd: json["ITEM_CD"] ?? "",
        vouchAmt: json["VOUCH_AMT"],
        itemName: json["ITEM_NAME"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "ITEM_CD": itemCd,
        "VOUCH_AMT": vouchAmt,
        "ITEM_NAME": itemName,
      };
}

class PartyDailyReport {
  PartyDailyReport({
    required this.accName,
    required this.accCd,
    required this.vouchAmt,
  });

  String accName;
  String accCd;
  dynamic vouchAmt;

  factory PartyDailyReport.fromJson(Map<String, dynamic> json) =>
      PartyDailyReport(
        accName: json["ACC_NAME"] ?? "",
        accCd: json["PARTY_CD"] ?? "",
        vouchAmt: json["VOUCH_AMT"],
      );

  Map<String, dynamic> toJson() => {
        "ACC_NAME": accName,
        "PARTY_CD": accCd,
        "VOUCH_AMT": vouchAmt,
      };
}

class OverviewDailyReport {
  OverviewDailyReport({required this.inventory, required this.account});

  List<OverviewDailyItemReport> inventory;
  List<OverviewDailyItemReport> account;

  factory OverviewDailyReport.fromJson(Map<String, dynamic> json) =>
      OverviewDailyReport(
          inventory: List<OverviewDailyItemReport>.from(json["inventory"]
              .map((x) => OverviewDailyItemReport.fromJson(x))),
          account: List<OverviewDailyItemReport>.from(
              json["account"].map((x) => OverviewDailyItemReport.fromJson(x))));

  Map<String, dynamic> toJson() => {
        "inventory": List<dynamic>.from(inventory.map((x) => x.toJson())),
        "account": List<dynamic>.from(account.map((x) => x.toJson())),
      };
}

class OverviewDailyItemReport {
  OverviewDailyItemReport(
      {required this.vouchAmt, required this.label, required this.record});

  String label;
  dynamic record;
  dynamic vouchAmt;

  factory OverviewDailyItemReport.fromJson(Map<String, dynamic> json) =>
      OverviewDailyItemReport(
          vouchAmt: json["VOUCH_AMT"].toString(),
          label: json["LABEL"],
          record: json['RECORD']);

  Map<String, dynamic> toJson() =>
      {"VOUCH_AMT": vouchAmt, "LABEL": label, "RECORD": record};
}
