import 'dart:convert';

DashboardV2Modal dashboardV2ModalFromJson(String str) =>
    DashboardV2Modal.fromJson(json.decode(str));

String dashboardV2ModalToJson(DashboardV2Modal data) =>
    json.encode(data.toJson());

class DashboardV2Modal {
  DashboardV2Modal({
    required this.message,
    required this.data,
  });

  String message;
  DashboardV2Data data;

  factory DashboardV2Modal.fromJson(Map<String, dynamic> json) =>
      DashboardV2Modal(
        message: json["message"] ?? "",
        data: DashboardV2Data.fromJson(json["data"] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data.toJson(),
      };
}

class DashboardV2Data {
  DashboardV2Data({
    required this.filters,
    required this.salesSummary,
    required this.revenueGrowthTrend,
    required this.grossProfit,
    required this.recentOrders,
    required this.topPartiesBySales,
    required this.topItemsBySales,
    required this.highestOrderedItems,
    required this.targetAchievement,
  });

  Filters filters;
  SalesSummary salesSummary;
  RevenueGrowthTrend revenueGrowthTrend;
  GrossProfit grossProfit;
  RecentOrders recentOrders;
  TopPartiesBySales topPartiesBySales;
  TopItemsBySales topItemsBySales;
  HighestOrderedItems highestOrderedItems;
  TargetAchievement targetAchievement;

  factory DashboardV2Data.fromJson(Map<String, dynamic> json) =>
      DashboardV2Data(
        filters: Filters.fromJson(json["filters"] ?? {}),
        salesSummary: SalesSummary.fromJson(json["salesSummary"] ?? {}),
        revenueGrowthTrend:
            RevenueGrowthTrend.fromJson(json["revenueGrowthTrend"] ?? {}),
        grossProfit: GrossProfit.fromJson(json["grossProfit"] ?? {}),
        recentOrders: RecentOrders.fromJson(json["recentOrders"] ?? {}),
        topPartiesBySales:
            TopPartiesBySales.fromJson(json["topPartiesBySales"] ?? {}),
        topItemsBySales:
            TopItemsBySales.fromJson(json["topItemsBySales"] ?? {}),
        highestOrderedItems:
            HighestOrderedItems.fromJson(json["highestOrderedItems"] ?? {}),
        targetAchievement:
            TargetAchievement.fromJson(json["targetAchievement"] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        "filters": filters.toJson(),
        "salesSummary": salesSummary.toJson(),
        "revenueGrowthTrend": revenueGrowthTrend.toJson(),
        "grossProfit": grossProfit.toJson(),
        "recentOrders": recentOrders.toJson(),
        "topPartiesBySales": topPartiesBySales.toJson(),
        "topItemsBySales": topItemsBySales.toJson(),
        "highestOrderedItems": highestOrderedItems.toJson(),
        "targetAchievement": targetAchievement.toJson(),
      };
}

class Filters {
  Filters({
    required this.fromDate,
    required this.toDate,
    required this.dateFilterApplied,
    required this.periodBaseDate,
    required this.periodBaseMode,
  });

  String fromDate;
  String toDate;
  bool dateFilterApplied;
  String periodBaseDate;
  String periodBaseMode;

  factory Filters.fromJson(Map<String, dynamic> json) => Filters(
        fromDate: json["fromDate"] ?? "",
        toDate: json["toDate"] ?? "",
        dateFilterApplied: json["dateFilterApplied"] ?? false,
        periodBaseDate: json["periodBaseDate"] ?? "",
        periodBaseMode: json["periodBaseMode"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "fromDate": fromDate,
        "toDate": toDate,
        "dateFilterApplied": dateFilterApplied,
        "periodBaseDate": periodBaseDate,
        "periodBaseMode": periodBaseMode,
      };
}

class SalesSummary {
  SalesSummary({
    required this.totalSales,
    required this.todaySales,
    required this.thisWeekSales,
    required this.thisMonthSales,
  });

  double totalSales;
  double todaySales;
  double thisWeekSales;
  double thisMonthSales;

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        totalSales: (json["totalSales"] as num?)?.toDouble() ?? 0.0,
        todaySales: (json["todaySales"] as num?)?.toDouble() ?? 0.0,
        thisWeekSales: (json["thisWeekSales"] as num?)?.toDouble() ?? 0.0,
        thisMonthSales: (json["thisMonthSales"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "totalSales": totalSales,
        "todaySales": todaySales,
        "thisWeekSales": thisWeekSales,
        "thisMonthSales": thisMonthSales,
      };
}

class RevenueGrowthTrend {
  RevenueGrowthTrend({
    required this.points,
    required this.peak,
    required this.growth,
  });

  List<Point> points;
  Point peak;
  Growth growth;

  factory RevenueGrowthTrend.fromJson(Map<String, dynamic> json) =>
      RevenueGrowthTrend(
        points: json["points"] != null
            ? List<Point>.from(json["points"].map((x) => Point.fromJson(x)))
            : [],
        peak: Point.fromJson(json["peak"] ?? {}),
        growth: Growth.fromJson(json["growth"] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        "points": List<dynamic>.from(points.map((x) => x.toJson())),
        "peak": peak.toJson(),
        "growth": growth.toJson(),
      };
}

class Point {
  Point({
    required this.date,
    required this.amount,
  });

  String date;
  double amount;

  factory Point.fromJson(Map<String, dynamic> json) => Point(
        date: json["date"] ?? "",
        amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "date": date,
        "amount": amount,
      };
}

class Growth {
  Growth({
    required this.percent,
    required this.label,
    required this.firstDayAmount,
    required this.lastDayAmount,
  });

  int percent;
  String label;
  double firstDayAmount;
  double lastDayAmount;

  factory Growth.fromJson(Map<String, dynamic> json) => Growth(
        percent: ((json["percent"] as num?)?.toInt() ?? 0),
        label: json["label"] ?? "0%",
        firstDayAmount: (json["firstDayAmount"] as num?)?.toDouble() ?? 0.0,
        lastDayAmount: (json["lastDayAmount"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "percent": percent,
        "label": label,
        "firstDayAmount": firstDayAmount,
        "lastDayAmount": lastDayAmount,
      };
}

class GrossProfit {
  GrossProfit({
    required this.amount,
    required this.formula,
  });

  double amount;
  String formula;

  factory GrossProfit.fromJson(Map<String, dynamic> json) => GrossProfit(
        amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
        formula: json["formula"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "amount": amount,
        "formula": formula,
      };
}

class RecentOrders {
  RecentOrders({
    required this.total,
    required this.count,
    required this.rows,
  });

  int total;
  int count;
  List<OrderRow> rows;

  factory RecentOrders.fromJson(Map<String, dynamic> json) => RecentOrders(
        total: ((json["total"] as num?)?.toInt() ?? 0),
        count: ((json["count"] as num?)?.toInt() ?? 0),
        rows: json["rows"] != null
            ? List<OrderRow>.from(json["rows"].map((x) => OrderRow.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "total": total,
        "count": count,
        "rows": List<dynamic>.from(rows.map((x) => x.toJson())),
      };
}

class OrderRow {
  OrderRow({
    required this.oId,
    required this.orderNo,
    required this.orderDate,
    required this.orderTime,
    required this.partyCode,
    required this.name,
    required this.mobile,
    required this.amount,
  });

  int oId;
  String orderNo;
  String orderDate;
  String orderTime;
  String partyCode;
  String name;
  String mobile;
  double amount;

  factory OrderRow.fromJson(Map<String, dynamic> json) => OrderRow(
        oId: ((json["oId"] as num?)?.toInt() ?? 0),
        orderNo: json["orderNo"] ?? "",
        orderDate: json["orderDate"] ?? "",
        orderTime: json["orderTime"] ?? "",
        partyCode: json["partyCode"] ?? "",
        name: json["name"] ?? "",
        mobile: json["mobile"] ?? "",
        amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "oId": oId,
        "orderNo": orderNo,
        "orderDate": orderDate,
        "orderTime": orderTime,
        "partyCode": partyCode,
        "name": name,
        "mobile": mobile,
        "amount": amount,
      };
}

class TopPartiesBySales {
  TopPartiesBySales({
    required this.total,
    required this.count,
    required this.rows,
  });

  double total;
  int count;
  List<PartyRow> rows;

  factory TopPartiesBySales.fromJson(Map<String, dynamic> json) =>
      TopPartiesBySales(
        total: (json["total"] as num?)?.toDouble() ?? 0.0,
        count: ((json["count"] as num?)?.toInt() ?? 0),
        rows: json["rows"] != null
            ? List<PartyRow>.from(json["rows"].map((x) => PartyRow.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "total": total,
        "count": count,
        "rows": List<dynamic>.from(rows.map((x) => x.toJson())),
      };
}

class PartyRow {
  PartyRow({
    required this.code,
    required this.accountName,
    required this.amount,
  });

  String code;
  String accountName;
  double amount;

  factory PartyRow.fromJson(Map<String, dynamic> json) => PartyRow(
        code: json["code"] ?? "",
        accountName: json["accountName"] ?? "",
        amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "accountName": accountName,
        "amount": amount,
      };
}

class TopItemsBySales {
  TopItemsBySales({
    required this.total,
    required this.count,
    required this.rows,
  });

  double total;
  int count;
  List<ItemRow> rows;

  factory TopItemsBySales.fromJson(Map<String, dynamic> json) =>
      TopItemsBySales(
        total: (json["total"] as num?)?.toDouble() ?? 0.0,
        count: ((json["count"] as num?)?.toInt() ?? 0),
        rows: json["rows"] != null
            ? List<ItemRow>.from(json["rows"].map((x) => ItemRow.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "total": total,
        "count": count,
        "rows": List<dynamic>.from(rows.map((x) => x.toJson())),
      };
}

class ItemRow {
  ItemRow({
    required this.itemCode,
    required this.itemName,
    required this.amount,
    required this.quantity,
  });

  String itemCode;
  String itemName;
  double amount;
  int quantity;

  factory ItemRow.fromJson(Map<String, dynamic> json) => ItemRow(
        itemCode: json["itemCode"] ?? "",
        itemName: json["itemName"] ?? "",
        amount: (json["amount"] as num?)?.toDouble() ?? 0.0,
        quantity: ((json["quantity"] as num?)?.toInt() ?? 0),
      );

  Map<String, dynamic> toJson() => {
        "itemCode": itemCode,
        "itemName": itemName,
        "amount": amount,
        "quantity": quantity,
      };
}

class HighestOrderedItems {
  HighestOrderedItems({
    required this.totalQuantity,
    required this.count,
    required this.rows,
  });

  int totalQuantity;
  int count;
  List<ItemRow> rows;

  factory HighestOrderedItems.fromJson(Map<String, dynamic> json) =>
      HighestOrderedItems(
        totalQuantity: ((json["totalQuantity"] as num?)?.toInt() ?? 0),
        count: ((json["count"] as num?)?.toInt() ?? 0),
        rows: json["rows"] != null
            ? List<ItemRow>.from(json["rows"].map((x) => ItemRow.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "totalQuantity": totalQuantity,
        "count": count,
        "rows": List<dynamic>.from(rows.map((x) => x.toJson())),
      };
}

class TargetAchievement {
  TargetAchievement({
    required this.targetAmount,
    required this.achievedAmount,
    required this.achievementPercent,
    required this.remainingAmount,
    required this.users,
    required this.totalUsers,
    required this.totals,
  });

  double targetAmount;
  double achievedAmount;
  double achievementPercent;
  double remainingAmount;
  List<TargetUser> users;
  int totalUsers;
  TargetTotals totals;

  factory TargetAchievement.fromJson(Map<String, dynamic> json) =>
      TargetAchievement(
        targetAmount: (json["targetAmount"] as num?)?.toDouble() ?? 0.0,
        achievedAmount: (json["achievedAmount"] as num?)?.toDouble() ?? 0.0,
        achievementPercent:
            ((json["achievementPercent"] as num?)?.toDouble() ?? 0.0),
        remainingAmount: (json["remainingAmount"] as num?)?.toDouble() ?? 0.0,
        users: json["users"] != null
            ? List<TargetUser>.from(
                json["users"].map((x) => TargetUser.fromJson(x)))
            : [],
        totalUsers: ((json["totalUsers"] as num?)?.toInt() ?? 0),
        totals: TargetTotals.fromJson(json["totals"] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        "targetAmount": targetAmount,
        "achievedAmount": achievedAmount,
        "achievementPercent": achievementPercent,
        "remainingAmount": remainingAmount,
        "users": List<dynamic>.from(users.map((x) => x.toJson())),
        "totalUsers": totalUsers,
        "totals": totals.toJson(),
      };
}

class TargetUser {
  TargetUser({
    required this.userCd,
    required this.userName,
    required this.targetAmount,
    required this.achievedAmount,
    required this.achievementPercent,
    required this.remainingAmount,
    required this.isSelf,
  });

  String userCd;
  String userName;
  double targetAmount;
  double achievedAmount;
  double achievementPercent;
  double remainingAmount;
  bool isSelf;

  factory TargetUser.fromJson(Map<String, dynamic> json) => TargetUser(
        userCd: json["userCd"] ?? "",
        userName: json["userName"] ?? "",
        targetAmount: (json["targetAmount"] as num?)?.toDouble() ?? 0.0,
        achievedAmount: (json["achievedAmount"] as num?)?.toDouble() ?? 0.0,
        achievementPercent:
            ((json["achievementPercent"] as num?)?.toDouble() ?? 0.0),
        remainingAmount: (json["remainingAmount"] as num?)?.toDouble() ?? 0.0,
        isSelf: json["isSelf"] ?? false,
      );

  Map<String, dynamic> toJson() => {
        "userCd": userCd,
        "userName": userName,
        "targetAmount": targetAmount,
        "achievedAmount": achievedAmount,
        "achievementPercent": achievementPercent,
        "remainingAmount": remainingAmount,
        "isSelf": isSelf,
      };
}

class TargetTotals {
  TargetTotals({
    required this.targetAmount,
    required this.achievedAmount,
    required this.achievementPercent,
    required this.remainingAmount,
  });

  double targetAmount;
  double achievedAmount;
  double achievementPercent;
  double remainingAmount;

  factory TargetTotals.fromJson(Map<String, dynamic> json) => TargetTotals(
        targetAmount: (json["targetAmount"] as num?)?.toDouble() ?? 0.0,
        achievedAmount: (json["achievedAmount"] as num?)?.toDouble() ?? 0.0,
        achievementPercent:
            ((json["achievementPercent"] as num?)?.toDouble() ?? 0.0),
        remainingAmount: (json["remainingAmount"] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        "targetAmount": targetAmount,
        "achievedAmount": achievedAmount,
        "achievementPercent": achievementPercent,
        "remainingAmount": remainingAmount,
      };
}
