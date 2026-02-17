// To parse this JSON data, do
//
//     final stockReportModal = stockReportModalFromJson(jsonString);

import 'dart:convert';

StockReportModal stockReportModalFromJson(String str) =>
    StockReportModal.fromJson(json.decode(str));

String stockReportModalToJson(StockReportModal data) =>
    json.encode(data.toJson());

class StockReportModal {
  List<DatumStockWiseSale> data;
  Payload payload;
  dynamic total;

  StockReportModal({
    required this.data,
    required this.payload,
    this.total,
  });

  factory StockReportModal.fromJson(Map<String, dynamic> json) =>
      StockReportModal(
          data: List<DatumStockWiseSale>.from(
              json["data"].map((x) => DatumStockWiseSale.fromJson(x))),
          payload: Payload.fromJson(json["payload"]),
          total: json['total']);

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "payload": payload.toJson(),
        'total': total
      };
}

class DatumStockWiseSale {
  String? exDt;
  String itemCd;
  String itemName;
  dynamic lastSize;
  dynamic rate;
  dynamic cStk;
  dynamic orStk;
  Deptment? deptment;
  dynamic nrate;
  dynamic totalValue;

  DatumStockWiseSale(
      {this.exDt,
      required this.itemCd,
      required this.itemName,
      required this.lastSize,
      required this.rate,
      required this.cStk,
      this.orStk,
      required this.deptment,
      required this.nrate,
      required this.totalValue});

  factory DatumStockWiseSale.fromJson(Map<String, dynamic> json) =>
      DatumStockWiseSale(
        exDt: json["EX_DT"],
        itemCd: json["ITEM_CD"],
        itemName: json["ITEM_NAME"],
        lastSize: json["LAST_SIZE"],
        rate: json["RATE"],
        cStk: json["C_STK"],
        orStk: json["OR_STK"],
        nrate: json["NRATE"],
        totalValue: json["TOTAL_VALUE"],
        deptment: json["deptment"] != null
            ? Deptment.fromJson(json["deptment"]) // Only parse if not null
            : null, // Otherwise, assign null,
      );

  Map<String, dynamic> toJson() => {
        "EX_DT": exDt,
        "ITEM_CD": itemCd,
        "ITEM_NAME": itemName,
        "LAST_SIZE": lastSize,
        "RATE": rate,
        "C_STK": cStk,
        "OR_STK": orStk,
        "NRATE": nrate,
        "TOTAL_VALUE": totalValue,
        "deptment": deptment?.toJson(),
      };
}

class Deptment {
  String deptCd;
  String deptName;
  int syncId;

  Deptment({
    required this.deptCd,
    required this.deptName,
    required this.syncId,
  });

  factory Deptment.fromJson(Map<String, dynamic> json) => Deptment(
        deptCd: json["DEPT_CD"],
        deptName: json["DEPT_NAME"],
        syncId: json["SYNC_ID"],
      );

  Map<String, dynamic> toJson() => {
        "DEPT_CD": deptCd,
        "DEPT_NAME": deptName,
        "SYNC_ID": syncId,
      };
}

class Payload {
  Pagination pagination;

  Payload({
    required this.pagination,
  });

  // factory Payload.fromJson(Map<String, dynamic> json) => Payload(
  //       pagination: Pagination.fromJson(json["pagination"]),
  //     );

  factory Payload.fromJson(Map<String, dynamic> json) {
    var paginationJson = json["pagination"];

    // If it's an empty string, set it to an empty map
    if (paginationJson is String && paginationJson.isEmpty) {
      paginationJson = {};  // Default to an empty map
    } else if (paginationJson is String) {
      // If it's a non-empty string, attempt to parse it as a JSON string
      paginationJson = jsonDecode(paginationJson);
    }

    // Ensure the pagination is treated as a Map<String, dynamic>
    if (paginationJson is Map) {
      paginationJson = Map<String, dynamic>.from(paginationJson); // Explicitly cast to Map<String, dynamic>
    }

    return Payload(
      pagination: Pagination.fromJson(paginationJson),
    );
  }

  Map<String, dynamic> toJson() => {
        "pagination": pagination.toJson(),
      };
}

class Pagination {
  String itemsPerPage;
  int page;
  int total;
  int lastPage;
  int from;
  int to;

  Pagination({
    required this.itemsPerPage,
    required this.page,
    required this.total,
    required this.lastPage,
    required this.from,
    required this.to,
  });

  // factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
  //       itemsPerPage: json["items_per_page"],
  //       page: json["page"],
  //       total: json["total"],
  //       lastPage: json["last_page"],
  //       from: json["from"],
  //       to: json["to"],
  //     );

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    // Handle nulls and missing values by providing default values
    itemsPerPage: json["items_per_page"] ?? "", // Default to an empty string if null
    page: json["page"] ?? 0,                    // Default to 0 if null
    total: json["total"] ?? 0,                  // Default to 0 if null
    lastPage: json["last_page"] ?? 0,           // Default to 0 if null
    from: json["from"] ?? 0,                    // Default to 0 if null
    to: json["to"] ?? 0,                        // Default to 0 if null
  );

  Map<String, dynamic> toJson() => {
        "items_per_page": itemsPerPage,
        "page": page,
        "total": total,
        "last_page": lastPage,
        "from": from,
        "to": to,
      };
}
