// To parse this JSON data, do
//
//     final profileModal = profileModalFromJson(jsonString);

import 'dart:convert';

import 'package:arham_corporation/models/settingmodal.dart';

ProfileModal profileModalFromJson(String str) =>
    ProfileModal.fromJson(json.decode(str));

String profileModalToJson(ProfileModal data) => json.encode(data.toJson());

class ProfileModal {
  String message;
  DataProfile data;

  ProfileModal({
    required this.message,
    required this.data,
  });

  factory ProfileModal.fromJson(Map<String, dynamic> json) => ProfileModal(
        message: json["message"],
        data: DataProfile.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data.toJson(),
      };
}

class DataProfile {
  List<String> moduleNos;
  dynamic userCd;
  dynamic compName;
  dynamic userName;
  dynamic syncId;
  dynamic userType;
  dynamic mobileno;
  dynamic validUpto;
  dynamic isPunchIn;
  OrderStartParty? orderStartParty;
  List<DatumSettings> profileSettings;
  License? license;
  List<Modules>? modulesList;

  DataProfile({
    required this.moduleNos,
    required this.userCd,
    required this.compName,
    required this.userName,
    required this.syncId,
    required this.userType,
    this.mobileno,
    this.validUpto,
    this.isPunchIn,
    this.orderStartParty,
    required this.profileSettings,
    this.license,
    this.modulesList,
  });

  factory DataProfile.fromJson(Map<String, dynamic> json) => DataProfile(
        moduleNos: json["MODULE_NOS"] != null
            ? List<String>.from(json["MODULE_NOS"].map((x) => x))
            : [],
        // Provide an empty list if null
        userCd: json["USER_CD"],
        compName: json["FIRM_NAME"],
        userName: json["USER_NAME"],
        syncId: json["SYNC_ID"],
        userType: json["USER_TYPE"],
        mobileno: json["MOBILENO"],
        validUpto: json['VALID_UPTO'],
        isPunchIn: json['IS_PUNCH_IN'] ?? false,
        orderStartParty: json["ORDER_START_PARTY"] == null
            ? null
            : OrderStartParty.fromJson(json["ORDER_START_PARTY"]),
        profileSettings: json["PROFILE_SETTINGS"] != null
            ? List<DatumSettings>.from(
                json["PROFILE_SETTINGS"].map((x) => DatumSettings.fromJson(x)))
            : [],
        // Provide an empty list if null
        license:
            json["license"] == null ? null : License.fromJson(json["license"]),
        // Parse license if present
        modulesList: json["modules"] != null
            ? List<Modules>.from(
                json["modules"].map((x) => Modules.fromJson(x)))
            : [],
      );

  // factory DataProfile.fromJson(Map<String, dynamic> json) => DataProfile(
  //       moduleNos: List<String>.from(json["MODULE_NOS"].map((x) => x)),
  //       userCd: json["USER_CD"],
  //       compName: json["FIRM_NAME"],
  //       userName: json["USER_NAME"],
  //       syncId: json["SYNC_ID"],
  //       userType: json["USER_TYPE"],
  //       mobileno: json["MOBILENO"],
  //       validUpto: json['VALID_UPTO'],
  //       isPunchIn: json['IS_PUNCH_IN'] ?? false,
  //       orderStartParty: json["ORDER_START_PARTY"] == null
  //           ? null
  //           : OrderStartParty.fromJson(json["ORDER_START_PARTY"]),
  //       profileSettings: List<DatumSettings>.from(
  //           json["PROFILE_SETTINGS"].map((x) => DatumSettings.fromJson(x))),
  //       license: json["license"] == null
  //           ? null
  //           : License.fromJson(json["license"]), // Parse license if present
  //     );

  Map<String, dynamic> toJson() => {
        "MODULE_NOS": List<dynamic>.from(moduleNos.map((x) => x)),
        "USER_CD": userCd,
        "COMP_NAME": compName,
        "USER_NAME": userName,
        "SYNC_ID": syncId,
        "USER_TYPE": userType,
        "MOBILENO": mobileno,
        "VALID_UPTO": validUpto,
        "IS_PUNCH_IN": isPunchIn,
        "ORDER_START_PARTY": orderStartParty?.toJson(),
        "PROFILE_SETTINGS": List<DatumSettings>.from(profileSettings.map((x) =>
            DatumSettings(
                sId: x.sId,
                settingName: x.settingName,
                syncId: x.syncId,
                value: x.value,
                variable: x.variable))),
        "license": license?.toJson(), // Serialize license if it exists
        "modules": List<Modules>.from(modulesList!.map((x) => Modules(
              iD: x.iD,
              uSERCD: x.uSERCD,
              mODULENO: x.mODULENO,
              rEADRIGHT: x.rEADRIGHT,
              wRITERIGHT: x.wRITERIGHT,
              uPDATERIGHT: x.uPDATERIGHT,
              dELETERIGHT: x.dELETERIGHT,
              pRINTRIGHT: x.pRINTRIGHT,
              uPDATEDAT: x.uPDATEDAT,
              cREATEDAT: x.cREATEDAT,
            ))),
      };
}

class OrderStartParty {
  String accName;
  String accCd;

  OrderStartParty({
    required this.accName,
    required this.accCd,
  });

  factory OrderStartParty.fromJson(Map<String, dynamic> json) =>
      OrderStartParty(
        accName: json["ACC_NAME"] ?? "",
        accCd: json["ACC_CD"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "ACC_NAME": accName,
        "ACC_CD": accCd,
      };
}

// License class to represent the LICENSE field
class License {
  String licStartDate;
  String licEndDate;
  int maxFirms;
  int maxUsers;
  String lastRenewalDate;

  License({
    required this.licStartDate,
    required this.licEndDate,
    required this.maxFirms,
    required this.maxUsers,
    required this.lastRenewalDate,
  });

  factory License.fromJson(Map<String, dynamic> json) => License(
        licStartDate: json["LIC_START_DATE"],
        licEndDate: json["LIC_END_DATE"],
        maxFirms: json["MAX_FIRMS"],
        maxUsers: json["MAX_USERS"],
        lastRenewalDate: json["LAST_RENEWAL_DATE"],
      );

  Map<String, dynamic> toJson() => {
        "LIC_START_DATE": licStartDate,
        "LIC_END_DATE": licEndDate,
        "MAX_FIRMS": maxFirms,
        "MAX_USERS": maxUsers,
        "LAST_RENEWAL_DATE": lastRenewalDate,
      };
}

class Modules {
  int? iD;
  String? uSERCD;
  String? mODULENO;
  bool? rEADRIGHT;
  bool? wRITERIGHT;
  bool? uPDATERIGHT;
  bool? dELETERIGHT;
  bool? pRINTRIGHT;
  String? uPDATEDAT;
  String? cREATEDAT;

  Modules(
      {this.iD,
      this.uSERCD,
      this.mODULENO,
      this.rEADRIGHT,
      this.wRITERIGHT,
      this.uPDATERIGHT,
      this.dELETERIGHT,
      this.pRINTRIGHT,
      this.uPDATEDAT,
      this.cREATEDAT});

  Modules.fromJson(Map<String, dynamic> json) {
    iD = json['ID'];
    uSERCD = json['USER_CD'];
    mODULENO = json['MODULE_NO'];
    rEADRIGHT = json['READ_RIGHT'];
    wRITERIGHT = json['WRITE_RIGHT'];
    uPDATERIGHT = json['UPDATE_RIGHT'];
    dELETERIGHT = json['DELETE_RIGHT'];
    pRINTRIGHT = json['PRINT_RIGHT'];
    uPDATEDAT = json['UPDATED_AT'];
    cREATEDAT = json['CREATED_AT'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ID'] = iD;
    data['USER_CD'] = uSERCD;
    data['MODULE_NO'] = mODULENO;
    data['READ_RIGHT'] = rEADRIGHT;
    data['WRITE_RIGHT'] = wRITERIGHT;
    data['UPDATE_RIGHT'] = uPDATERIGHT;
    data['DELETE_RIGHT'] = dELETERIGHT;
    data['PRINT_RIGHT'] = pRINTRIGHT;
    data['UPDATED_AT'] = uPDATEDAT;
    data['CREATED_AT'] = cREATEDAT;
    return data;
  }

  @override
  String toString() {
    return 'Modules('
        'iD: $iD, '
        'uSERCD: $uSERCD, '
        'mODULENO: $mODULENO, '
        'rEADRIGHT: $rEADRIGHT, '
        'wRITERIGHT: $wRITERIGHT, '
        'uPDATERIGHT: $uPDATERIGHT, '
        'dELETERIGHT: $dELETERIGHT, '
        'pRINTRIGHT: $pRINTRIGHT, '
        'uPDATEDAT: $uPDATEDAT, '
        'cREATEDAT: $cREATEDAT'
        ')';
  }
}
