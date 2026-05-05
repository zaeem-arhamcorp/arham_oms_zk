// To parse this JSON data, do
//
//     final deptmentListModal = deptmentListModalFromJson(jsonString);

import 'dart:convert';

DeptmentListModal deptmentListModalFromJson(String str) =>
    DeptmentListModal.fromJson(json.decode(str));

String deptmentListModalToJson(DeptmentListModal data) =>
    json.encode(data.toJson());

class DeptmentListModal {
  String message;
  List<DatumDeptment> data;

  DeptmentListModal({
    required this.message,
    required this.data,
  });

  factory DeptmentListModal.fromJson(Map<String, dynamic> json) =>
      DeptmentListModal(
        message: json["message"],
        data: List<DatumDeptment>.from(
            json["data"].map((x) => DatumDeptment.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumDeptment {
  dynamic deptCd;
  dynamic deptName;
  dynamic syncId;

  DatumDeptment({
    required this.deptCd,
    required this.deptName,
    required this.syncId,
  });

  factory DatumDeptment.fromJson(Map<String, dynamic> json) => DatumDeptment(
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
