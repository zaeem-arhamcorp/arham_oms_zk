import 'dart:convert';

CityListModal cityListModalFromJson(String str) =>
    CityListModal.fromJson(json.decode(str));

String cityListModalToJson(CityListModal data) => json.encode(data.toJson());

class CityListModal {
  String message;
  List<DatumCity> data;

  CityListModal({
    required this.message,
    required this.data,
  });

  factory CityListModal.fromJson(Map<String, dynamic> json) => CityListModal(
        message: json["message"],
        data: List<DatumCity>.from(
            json["data"].map((x) => DatumCity.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumCity {
  dynamic city;
  dynamic syncId;

  DatumCity({
    required this.city,
    required this.syncId,
  });

  factory DatumCity.fromJson(Map<String, dynamic> json) => DatumCity(
        city: json["CITY"],
        syncId: json["SYNC_ID"],
      );

  Map<String, dynamic> toJson() => {
        "CITY": city,
        "SYNC_ID": syncId,
      };
}
