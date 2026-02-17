class NarrationModel {
  String? message;
  List<Data>? data;

  NarrationModel({this.message, this.data});

  NarrationModel.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Data {
  int? nARRID;
  String? nARRNAME;
  String? nARRTYPE;
  int? sYNCID;
  String? uPDATEDAT;
  String? cREATEDAT;

  Data(
      {this.nARRID,
      this.nARRNAME,
      this.nARRTYPE,
      this.sYNCID,
      this.uPDATEDAT,
      this.cREATEDAT});

  Data.fromJson(Map<String, dynamic> json) {
    nARRID = json['NARR_ID'];
    nARRNAME = json['NARR_NAME'];
    nARRTYPE = json['NARR_TYPE'];
    sYNCID = json['SYNC_ID'];
    uPDATEDAT = json['UPDATED_AT'];
    cREATEDAT = json['CREATED_AT'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['NARR_ID'] = nARRID;
    data['NARR_NAME'] = nARRNAME;
    data['NARR_TYPE'] = nARRTYPE;
    data['SYNC_ID'] = sYNCID;
    data['UPDATED_AT'] = uPDATEDAT;
    data['CREATED_AT'] = cREATEDAT;
    return data;
  }
}
