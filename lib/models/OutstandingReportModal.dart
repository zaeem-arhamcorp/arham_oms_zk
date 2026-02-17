import 'dart:convert';

OutstandingReportModal OutstandingReportModalFromJson(String str) =>
    OutstandingReportModal.fromJson(json.decode(str));

String OutstandingReportModalToJson(OutstandingReportModal data) =>
    json.encode(data.toJson());

class OutstandingReportModal {
  OutstandingReportModal({
    required this.message,
    required this.data,
  });

  String message;
  List<DatumOutstandingSale> data;

  factory OutstandingReportModal.fromJson(Map<String, dynamic> json) =>
      OutstandingReportModal(
        message: json["message"],
        data: List<DatumOutstandingSale>.from(
            json["data"].map((x) => DatumOutstandingSale.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumOutstandingSale {
  DatumOutstandingSale({
    required this.partyCd,
    required this.sumVouchAmt,
    required this.sumPaidAmt,
    required this.sumOsAmt,
    required this.accName,
    required this.syncId,
    required this.accCd,
    required this.city,
  });

  dynamic partyCd;
  dynamic sumVouchAmt;
  dynamic sumPaidAmt;
  dynamic sumOsAmt;
  dynamic syncId;
  dynamic accName;
  dynamic accCd;
  dynamic city;

  factory DatumOutstandingSale.fromJson(Map<String, dynamic> json) =>
      DatumOutstandingSale(
        partyCd: json["PARTY_CD"],
        sumVouchAmt: json["SUM_VOUCH_AMT"],
        sumPaidAmt: json["SUM_PAID_AMT"],
        sumOsAmt: json['SUM_OS_AMT'],
        syncId: json['SYNC_ID'],
        accName: json['account.ACC_NAME'],
        accCd: json['account.ACC_CD'],
        city: json['account.CITY'],
      );

  Map<String, dynamic> toJson() => {
        "PARTY_CD": partyCd,
        "SUM_VOUCH_AMT": sumVouchAmt,
        "SUM_PAID_AMT": sumPaidAmt,
        "SUM_OS_AMT": sumOsAmt,
        "SYNC_ID": syncId,
        "account.ACC_NAME": accName,
        "account.ACC_CD": accCd,
        "account.CITY": city
      };
}
