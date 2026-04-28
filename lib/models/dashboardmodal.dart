// To parse this JSON data, do
//
//     final dashboardModal = dashboardModalFromJson(jsonString);

import 'dart:convert';

DashboardModal dashboardModalFromJson(String str) =>
    DashboardModal.fromJson(json.decode(str));

String dashboardModalToJson(DashboardModal data) => json.encode(data.toJson());

class DashboardModal {
  DashboardModal({
    required this.message,
    required this.data,
  });

  String message;
  DashboardData data;

  factory DashboardModal.fromJson(Map<String, dynamic> json) => DashboardModal(
        message: json["message"],
        data: DashboardData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data.toJson(),
      };
}

class DashboardData {
  DashboardData({
    required this.label,
    required this.labelData,
  });

  String? label;
  LabelData labelData;

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        label: json["label"],
        labelData: LabelData.fromJson(json["label_data"]),
      );

  Map<String, dynamic> toJson() => {
        "label": label,
        "label_data": labelData.toJson(),
      };
}

class LabelData {
  LabelData({
    required this.totalSales,
    required this.week,
    required this.month,
    required this.transaction,
    required this.today,
    this.targetAchievement,
  });

  String totalSales;
  String week;
  String month;
  String today;
  List<Transaction> transaction;
  TargetAchievement? targetAchievement;

  factory LabelData.fromJson(Map<String, dynamic> json) => LabelData(
        totalSales: json["TOTAL_SALES"] ?? "0",
        week: json["WEEK"] ?? "0",
        month: json["MONTH"] ?? "0",
        today: json['TODAY'] ?? "0",
        transaction: json["transaction"] != null
            ? List<Transaction>.from(
                json["transaction"].map((x) => Transaction.fromJson(x)))
            : [],
        targetAchievement: json["targetAchievement"] != null
            ? TargetAchievement.fromJson(json["targetAchievement"])
            : null,
      );

  Map<String, dynamic> toJson() => {
        "TOTAL_SALES": totalSales,
        "WEEK": week,
        "MONTH": month,
        "TODAY": today,
        "transaction": List<dynamic>.from(transaction.map((x) => x.toJson())),
        "targetAchievement": targetAchievement?.toJson(),
      };
}

class TargetAchievement {
  TargetAchievement({
    required this.userCd,
    required this.userName,
    required this.target,
    required this.achieved,
    required this.percent,
    required this.remaining,
  });

  String userCd;
  String userName;
  double target;
  double achieved;
  double percent;
  double remaining;

  factory TargetAchievement.fromJson(Map<String, dynamic> json) =>
      TargetAchievement(
        userCd: json["USER_CD"]?.toString() ?? "",
        userName: json["USER_NAME"]?.toString() ?? "",
        target: _toDouble(json["TARGET"]),
        achieved: _toDouble(json["ACHIEVED"]),
        percent: _toDouble(json["PERCENT"]),
        remaining: _toDouble(json["REMAINING"]),
      );

  Map<String, dynamic> toJson() => {
        "USER_CD": userCd,
        "USER_NAME": userName,
        "TARGET": target,
        "ACHIEVED": achieved,
        "PERCENT": percent,
        "REMAINING": remaining,
      };
}

double _toDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0.0;
}

class Transaction {
  Transaction(
      {required this.name,
      required this.amount,
      required this.orderNo,
      required this.mobile,
      required this.orderDate,
      required this.accCd});

  String name;
  dynamic amount;
  String orderNo;
  String mobile;
  String accCd;
  String orderDate;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
      name: json["NAME"] ?? "",
      accCd: json["ACC_CD"] ?? "",
      amount: json["AMOUNT"] ?? 0,
      orderNo: json["ORDER_NO"] ?? "",
      mobile: json['MOBILE'] ?? "",
      orderDate: json['ORDER_DATE'] ?? "");

  Map<String, dynamic> toJson() => {
        "NAME": name,
        "AMOUNT": amount,
        "ORDER_NO": orderNo,
        "MOBILE": mobile,
        "ACC_CD": accCd,
        "ORDER_DATE": orderDate
      };
}
