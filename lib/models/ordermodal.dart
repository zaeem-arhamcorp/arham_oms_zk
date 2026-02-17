// To parse this JSON data, do
//
//     final ordermodal = ordermodalFromJson(jsonString);

import 'dart:convert';

import 'package:hive/hive.dart';
part 'ordermodal.g.dart';

Ordermodal ordermodalFromJson(String str) =>
    Ordermodal.fromJson(json.decode(str));

String ordermodalToJson(Ordermodal data) => json.encode(data.toJson());

@HiveType(typeId: 3)
class Ordermodal {
  Ordermodal({
    required this.partyCd,
    required this.netAmt,
    required this.orderItm,
  });
  @HiveField(0)
  String partyCd;
  @HiveField(1)
  String netAmt;
  @HiveField(2)
  List<OrderItm> orderItm;

  factory Ordermodal.fromJson(Map<String, dynamic> json) => Ordermodal(
        partyCd: json["partyCd"],
        netAmt: json["netAmt"],
        orderItm: List<OrderItm>.from(
            json["orderItm"].map((x) => OrderItm.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "partyCd": partyCd,
        "netAmt": netAmt,
        "orderItm": List<dynamic>.from(orderItm.map((x) => x.toJson())),
      };
}

@HiveType(typeId: 4)
class OrderItm {
  OrderItm(
      {required this.itemCd,
      required this.qty,
      required this.rate,
      required this.amt,
      required this.otherDesc,
      this.nrate});
  @HiveField(0)
  String itemCd;
  @HiveField(1)
  int qty;
  @HiveField(2)
  double rate;
  @HiveField(3)
  double amt;
  @HiveField(4)
  String otherDesc;
  @HiveField(5)
  double? nrate;

  factory OrderItm.fromJson(Map<String, dynamic> json) => OrderItm(
        itemCd: json["itemCd"],
        qty: json["qty"],
        rate: json["rate"],
        amt: json["amt"],
        otherDesc: json["otherDesc"],
        nrate: json["nrate"],
      );

  Map<String, dynamic> toJson() => {
        "itemCd": itemCd,
        "qty": qty,
        "rate": rate,
        "amt": amt,
        "otherDesc": otherDesc,
        "nrate": nrate
      };
}
