class UserExitsResponse {
  bool? status;
  String? message;
  UserExitsModel? data;

  UserExitsResponse({this.status, this.message, this.data});

  UserExitsResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? UserExitsModel.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class UserExitsModel {
  String? uSERCD;
  String? cUSTID;
  String? uSERNAME;
  String? mOBILENO;
  num? iSVERIFIED;

  UserExitsModel(
      {this.uSERCD,
      this.cUSTID,
      this.uSERNAME,
      this.mOBILENO,
      this.iSVERIFIED});

  UserExitsModel.fromJson(Map<String, dynamic> json) {
    uSERCD = json['USER_CD'];
    cUSTID = json['CUST_ID'];
    uSERNAME = json['USER_NAME'];
    mOBILENO = json['MOBILENO'];
    iSVERIFIED = json['IS_VERIFIED'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['USER_CD'] = uSERCD;
    data['CUST_ID'] = cUSTID;
    data['USER_NAME'] = uSERNAME;
    data['MOBILENO'] = mOBILENO;
    data['IS_VERIFIED'] = iSVERIFIED;
    return data;
  }
}
