// To parse this JSON data, do
//
//     final orderlistModal = orderlistModalFromJson(jsonString);

import 'dart:convert';

import 'package:hive_flutter/adapters.dart';
part 'orderlistModal.g.dart';
OrderlistModal orderlistModalFromJson(String str) => OrderlistModal.fromJson(json.decode(str));

String orderlistModalToJson(OrderlistModal data) => json.encode(data.toJson());

class OrderlistModal {
  OrderlistModal({
    required this.data,
    required this.message,
  });

  List<DatumOrderList> data;
  String message;

  factory OrderlistModal.fromJson(Map<String, dynamic> json) => OrderlistModal(
    data: List<DatumOrderList>.from(json["data"].map((x) => DatumOrderList.fromJson(x))),
    message: json["message"],
  );

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
    "message": message,
  };
}
@HiveType(typeId: 1)
class DatumOrderList {
  DatumOrderList({
     this.oId,
     this.vouchDt,
     this.vouchTime,
     this.partyCd,
    this.lastEdit,
    this.entryComp,
    this.billNo,
     this.syncId,
    this.billDt,
     this.netAmt,
     this.orderNo,
     required this.ordritms,
  });
  @HiveField(0)
  dynamic oId;
  @HiveField(1)
  dynamic vouchDt;
  @HiveField(2)
  dynamic vouchTime;
  @HiveField(3)
  dynamic partyCd;
  @HiveField(4)
  dynamic lastEdit;
  @HiveField(5)
  dynamic entryComp;
  @HiveField(6)
  dynamic billNo;
  @HiveField(7)
  dynamic syncId;
  @HiveField(8)
  dynamic billDt;
  @HiveField(9)
  dynamic netAmt;
  @HiveField(10)
  dynamic orderNo;
  @HiveField(11)
  List<DataOrdritm> ordritms;

  factory DatumOrderList.fromJson(Map<String, dynamic> json) => DatumOrderList(
    oId: json["oId"],
    vouchDt: DateTime.parse(json["VOUCH_DT"]),
    vouchTime: json["VOUCH_TIME"],
    partyCd: json["PARTY_CD"],
    lastEdit: json["LAST_EDIT"],
    entryComp: json["ENTRY_COMP"],
    billNo: json["BILL_NO"],
    syncId: json["SYNC_ID"],
    billDt: json["BILL_DT"],
    netAmt: json["NET_AMT"],
    orderNo: json["ORDER_NO"],
    ordritms: List<DataOrdritm>.from(json["ordritms"].map((x) => DataOrdritm.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "oId": oId,
    "VOUCH_DT": "${vouchDt.year.toString().padLeft(4, '0')}-${vouchDt.month.toString().padLeft(2, '0')}-${vouchDt.day.toString().padLeft(2, '0')}",
    "VOUCH_TIME": vouchTime,
    "PARTY_CD": partyCd,
    "LAST_EDIT": lastEdit,
    "ENTRY_COMP": entryComp,
    "BILL_NO": billNo,
    "SYNC_ID": syncId,
    "BILL_DT": billDt,
    "NET_AMT": netAmt,
    "ORDER_NO": orderNo,
    "ordritms": List<dynamic>.from(ordritms.map((x) => x.toJson())),
  };
}
@HiveType(typeId: 2)
class DataOrdritm {
  DataOrdritm({
     this.odId,
     this.oId,
    this.itemSr,
     this.vouchDt,
     this.vouchTime,
     this.pCd,
     this.itemCd,
    this.lastEdit,
     this.quantity,
     this.rate,
     this.syncId,
     this.amount,
    this.otherDesc,
  });
  @HiveField(0)
  dynamic odId;
  @HiveField(1)
  dynamic oId;
  @HiveField(2)
  dynamic itemSr;
  @HiveField(3)
  dynamic vouchDt;
  @HiveField(4)
  dynamic vouchTime;
  @HiveField(5)
  dynamic pCd;
  @HiveField(6)
  dynamic itemCd;
  @HiveField(7)
  dynamic lastEdit;
  @HiveField(8)
  dynamic quantity;
  @HiveField(9)
  dynamic rate;
  @HiveField(10)
  dynamic syncId;
  @HiveField(11)
  dynamic amount;
  @HiveField(12)
  dynamic otherDesc;

  factory DataOrdritm.fromJson(Map<String, dynamic> json) => DataOrdritm(
    odId: json["odId"],
    oId: json["oId"],
    itemSr: json["ITEM_SR"],
    vouchDt: DateTime.parse(json["VOUCH_DT"]),
    vouchTime: json["VOUCH_TIME"],
    pCd: json["P_CD"],
    itemCd: json["ITEM_CD"],
    lastEdit: json["LAST_EDIT"],
    quantity: json["QUANTITY"],
    rate: json["RATE"],
    syncId: json["SYNC_ID"],
    amount: json["AMOUNT"],
    otherDesc: json["OTHER_DESC"],
  );

  Map<String, dynamic> toJson() => {
    "odId": odId,
    "oId": oId,
    "ITEM_SR": itemSr,
    "VOUCH_DT": "${vouchDt.year.toString().padLeft(4, '0')}-${vouchDt.month.toString().padLeft(2, '0')}-${vouchDt.day.toString().padLeft(2, '0')}",
    "VOUCH_TIME": vouchTime,
    "P_CD": pCd,
    "ITEM_CD": itemCd,
    "LAST_EDIT": lastEdit,
    "QUANTITY": quantity,
    "RATE": rate,
    "SYNC_ID": syncId,
    "AMOUNT": amount,
    "OTHER_DESC": otherDesc,
  };
}
