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
  });

  String totalSales;
  String week;
  String month;
  String today;
  List<Transaction> transaction;

  factory LabelData.fromJson(Map<String, dynamic> json) => LabelData(
        totalSales: json["total_sales"] ?? "0",
        week: json["week"] ?? "0",
        month: json["month"] ?? "0",
        today: json['today'] ?? "0",
        transaction: json["transaction"] != null
            ? List<Transaction>.from(
                json["transaction"].map((x) => Transaction.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "total_sales": totalSales,
        "week": week,
        "month": month,
        "today": today,
        "transaction": List<dynamic>.from(transaction.map((x) => x.toJson())),
      };
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
      name: json["name"] ?? "",
      accCd: json["accCd"] ?? "",
      amount: json["amount"] ?? 0,
      orderNo: json["orderNo"] ?? "",
      mobile: json['mobile'] ?? "",
      orderDate: json['orderDate'] ?? "");

  Map<String, dynamic> toJson() => {
        "name": name,
        "amount": amount,
        "orderNo": orderNo,
        "mobile": mobile,
        "accCd": accCd,
        "orderDate": orderDate
      };
}
