import 'dart:convert';

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
      this.imgUrl,
      this.remark,
      this.sId,
      required this.account,
      required this.user});

  dynamic vouchDt;
  dynamic bookCd;
  dynamic partyBl;
  dynamic partyCd;
  dynamic narration;
  dynamic vouchType;
  dynamic vouchAmt;
  dynamic imgUrl;
  dynamic remark;
  dynamic sId;
  Account account;
  User user;

  factory DatumSalesRegisterReport.fromJson(Map<String, dynamic> json) =>
      DatumSalesRegisterReport(
        vouchDt: json["VOUCH_DT"],
        bookCd: json["BOOK_CD"],
        partyBl: json["PARTY_BL"],
        partyCd: json["PARTY_CD"],
        narration: json["NARRATION"],
        vouchType: json["VOUCH_TYPE"],
        vouchAmt: json["VOUCH_AMT"],
        imgUrl: json['IMG_URL'] ?? "",
        remark: json['REMARK'] ?? "",
        sId: json['S_ID'] ?? "",
        account: Account.fromJson(json['partyAccount']),
        user: User.fromJson(json['usermast']),
      );

  Map<String, dynamic> toJson() => {
        "VOUCH_DT": vouchDt,
        "BOOK_CD": bookCd,
        "PARTY_BL": partyBl,
        "PARTY_CD": partyCd,
        "NARRATION": narration,
        "VOUCH_TYPE": vouchType,
        "VOUCH_AMT": vouchAmt,
        "IMG_URL": imgUrl,
        "REMARK": remark,
        "S_ID": sId,
        "partyAccount": account.toJson(),
        "usermast": user.toJson(),
      };
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
}

class User {
  User({
    required this.userCd,
    required this.userName,
  });

  String userCd;
  String userName;

  factory User.fromJson(Map<String, dynamic> json) => User(
        userCd: json["USER_CD"],
        userName: json["USER_NAME"],
      );

  Map<String, dynamic> toJson() => {
        "USER_CD": userCd,
        "USER_NAME": userName,
      };
}
