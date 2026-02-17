// To parse this JSON data, do
//
//     final utlityModal = utlityModalFromJson(jsonString);

import 'dart:convert';

UtlityModal utlityModalFromJson(String str) =>
    UtlityModal.fromJson(json.decode(str));

String utlityModalToJson(UtlityModal data) => json.encode(data.toJson());

class UtlityModal {
  String message;
  DatumUtlity data;

  UtlityModal({
    required this.message,
    required this.data,
  });

  factory UtlityModal.fromJson(Map<String, dynamic> json) => UtlityModal(
        message: json["message"],
        data: DatumUtlity.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data.toJson(),
      };
}

class DatumUtlity {
  dynamic id;
  dynamic androidAppVersion;
  dynamic iosAppVersion;
  bool isSignUp;

  DatumUtlity(
      {required this.id,
      required this.androidAppVersion,
      required this.iosAppVersion,
      required this.isSignUp});

  factory DatumUtlity.fromJson(Map<String, dynamic> json) => DatumUtlity(
      id: json["id"],
      androidAppVersion: json["ANDROID_APP_VERSION"],
      iosAppVersion: json['IOS_APP_VERSION'],
      isSignUp: json['IS_SIGN_UP']);

  Map<String, dynamic> toJson() => {
        "id": id,
        "ANDROID_APP_VERSION": androidAppVersion,
        "IOS_APP_VERSION": iosAppVersion,
        "IS_SIGN_UP": isSignUp
      };
}
