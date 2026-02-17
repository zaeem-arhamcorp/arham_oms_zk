import 'dart:convert';

NarrationModal narrationModalFromJson(String str) =>
    NarrationModal.fromJson(json.decode(str));

String narrationModalToJson(NarrationModal data) => json.encode(data.toJson());

class NarrationModal {
  String message;
  List<DatumNarration> data;

  NarrationModal({
    required this.message,
    required this.data,
  });

  factory NarrationModal.fromJson(Map<String, dynamic> json) => NarrationModal(
        message: json["message"],
        data: List<DatumNarration>.from(
            json["data"].map((x) => DatumNarration.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumNarration {
  dynamic NARR_NAME;
  dynamic NARR_TYPE;
  dynamic SYNC_ID;

  DatumNarration({
    required this.NARR_NAME,
    required this.NARR_TYPE,
    required this.SYNC_ID,
  });

  factory DatumNarration.fromJson(Map<String, dynamic> json) => DatumNarration(
        NARR_NAME: json["NARR_NAME"],
        NARR_TYPE: json["NARR_TYPE"],
        SYNC_ID: json["SYNC_ID"],
      );

  Map<String, dynamic> toJson() =>
      {"NARR_NAME": NARR_NAME, "NARR_TYPE": NARR_TYPE, "SYNC_ID": SYNC_ID};
}
