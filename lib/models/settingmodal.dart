// To parse this JSON data, do
//
//     final settingModal = settingModalFromJson(jsonString);

import 'dart:convert';

SettingModal settingModalFromJson(String str) =>
    SettingModal.fromJson(json.decode(str));

String settingModalToJson(SettingModal data) => json.encode(data.toJson());

class SettingModal {
  String message;
  List<DatumSettings> data;

  SettingModal({
    required this.message,
    required this.data,
  });

  factory SettingModal.fromJson(Map<String, dynamic> json) => SettingModal(
        message: json["message"],
        data: json["data"] != null
            ? List<DatumSettings>.from(
                json["data"].map((x) => DatumSettings.fromJson(x)))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumSettings {
  dynamic sId;
  dynamic settingName;
  dynamic variable;
  dynamic value;
  dynamic syncId;
  dynamic valueAmt;

  DatumSettings({
    this.sId,
    this.settingName,
    this.variable,
    this.value,
    this.syncId,
    this.valueAmt,
  });

  factory DatumSettings.fromJson(Map<String, dynamic> json) => DatumSettings(
        sId: json["sId"],
        settingName: json["SETTING_NAME"] ?? "",
        variable: json["VARIABLE"] ?? "",
        value: json["VALUE"] ?? "",
        syncId: json["SYNC_ID"],
    valueAmt: json["VALUE_AMT"],
      );

  Map<String, dynamic> toJson() => {
        "sId": sId,
        "SETTING_NAME": settingName,
        "VARIABLE": variable,
        "VALUE": value,
        "SYNC_ID": syncId,
        "VALUE_AMT": valueAmt,
      };
}
