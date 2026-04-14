// To parse this JSON data, do
//
//     final personModal = personModalFromJson(jsonString);

import 'dart:convert';

PersonModal personModalFromJson(String str) =>
    PersonModal.fromJson(json.decode(str));

String personModalToJson(PersonModal data) => json.encode(data.toJson());

OpPersonModal opPersonModalFromJson(String str) =>
    OpPersonModal.fromJson(json.decode(str));

String opPersonModalToJson(OpPersonModal data) => json.encode(data.toJson());

ModulesModal modulesModalFromJson(String str) =>
    ModulesModal.fromJson(json.decode(str));

String modulesModalToJson(ModulesModal data) => json.encode(data.toJson());

class ModulesModal {
  String message;
  List<DatumModules> data;

  ModulesModal({
    required this.message,
    required this.data,
  });

  factory ModulesModal.fromJson(Map<String, dynamic> json) => ModulesModal(
        message: json["message"],
        data: List<DatumModules>.from(
            json["data"].map((x) => DatumModules.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumModules {
  dynamic moduleName;
  dynamic moduleNo;
  dynamic moduleType;
  dynamic sORTING;
  dynamic aPPTYPE;
  dynamic appTypeCategory;
  dynamic READ_RIGHT;
  dynamic WRITE_RIGHT;
  dynamic UPDATE_RIGHT;
  dynamic DELETE_RIGHT;
  dynamic PRINT_RIGHT;
  List<dynamic> role;

  DatumModules(
      {required this.moduleName,
      required this.moduleNo,
      required this.moduleType,
      required this.sORTING,
      required this.aPPTYPE,
      required this.appTypeCategory,
      required this.role,
      required this.READ_RIGHT,
      required this.WRITE_RIGHT,
      required this.UPDATE_RIGHT,
      required this.DELETE_RIGHT,
      required this.PRINT_RIGHT});

  factory DatumModules.fromJson(Map<String, dynamic> json) => DatumModules(
      moduleName: json["MODULE_NAME"],
      moduleNo: json["MODULE_NO"],
      moduleType: json["MODULE_TYPE"],
      sORTING: json["SORTING"],
      aPPTYPE: json["APP_TYPE"],
      appTypeCategory: json["APP_TYPE_CATEGORY"],
      READ_RIGHT: json["READ_RIGHT"],
      WRITE_RIGHT: json["WRITE_RIGHT"],
      UPDATE_RIGHT: json["UPDATE_RIGHT"],
      DELETE_RIGHT: json["DELETE_RIGHT"],
      PRINT_RIGHT: json["PRINT_RIGHT"],
      role: json['USER_TYPE']);

  Map<String, dynamic> toJson() => {
        "MODULE_NAME": moduleName,
        "MODULE_NO": moduleNo,
        "MODULE_TYPE": moduleType,
        "SORTING": sORTING,
        "APP_TYPE": aPPTYPE,
        "APP_TYPE_CATEGORY": appTypeCategory,
        "READ_RIGHT": READ_RIGHT,
        "WRITE_RIGHT": WRITE_RIGHT,
        "UPDATE_RIGHT": UPDATE_RIGHT,
        "DELETE_RIGHT": DELETE_RIGHT,
        "PRINT_RIGHT": PRINT_RIGHT,
        "USER_TYPE": role,
      };
}

class PersonModal {
  List<DatumPerson> data;
  Payload payload;

  PersonModal({
    required this.data,
    required this.payload,
  });

  factory PersonModal.fromJson(Map<String, dynamic> json) => PersonModal(
        data: List<DatumPerson>.from(
            json["data"].map((x) => DatumPerson.fromJson(x))),
        payload: Payload.fromJson(json["payload"]),
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
        "payload": payload.toJson(),
      };
}

class OpPersonModal {
  List<DatumPerson> data;

  OpPersonModal({
    required this.data,
  });

  factory OpPersonModal.fromJson(Map<String, dynamic> json) => OpPersonModal(
        data: List<DatumPerson>.from(
            json["data"].map((x) => DatumPerson.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class DatumPerson {
  dynamic userCd;
  dynamic compName;
  dynamic userPwd;
  dynamic userName;
  dynamic syncId;
  dynamic moduleNos;
  dynamic qryType;
  dynamic loginPartyCd;
  dynamic userType;
  dynamic id;
  dynamic impDtTm;
  dynamic extrFltr1;
  dynamic mobileno;
  dynamic blacklist;
  dynamic startDate;
  dynamic validUpto;
  dynamic firmUsers;
  dynamic modules;
  dynamic userImageUrl;
  dynamic email;

  DatumPerson({
    required this.userCd,
    required this.compName,
    required this.userPwd,
    required this.userName,
    required this.syncId,
    required this.moduleNos,
    required this.qryType,
    this.loginPartyCd,
    required this.userType,
    required this.id,
    this.impDtTm,
    required this.extrFltr1,
    this.mobileno,
    this.blacklist,
    this.startDate,
    this.validUpto,
    this.firmUsers,
    this.modules,
    this.userImageUrl,
    this.email,
  });

  factory DatumPerson.fromJson(Map<String, dynamic> json) => DatumPerson(
        userCd: json["USER_CD"],
        compName: json["COMP_NAME"],
        userPwd: json["USER_PWD"],
        userName: json["USER_NAME"],
        syncId: json["SYNC_ID"],
        moduleNos: json["MODULE_NOS"],
        qryType: json["QRY_TYPE"],
        loginPartyCd: json["LOGIN_PARTY_CD"],
        userType: json["USER_TYPE"],
        id: json["id"],
        impDtTm: json["IMP_DT_TM"],
        extrFltr1: json["EXTR_FLTR1"],
        mobileno: json["MOBILENO"],
        blacklist: json["BLACKLIST"],
        startDate: json["START_DATE"],
        validUpto: json["VALID_UPTO"],
        firmUsers: json["firm_user_links"],
        modules: json["modules"],
        userImageUrl: json["USER_IMAGE_URL"],
        email: json["emailID"],
      );

  Map<String, dynamic> toJson() => {
        "USER_CD": userCd,
        "COMP_NAME": compName,
        "USER_PWD": userPwd,
        "USER_NAME": userName,
        "SYNC_ID": syncId,
        "MODULE_NOS": moduleNos,
        "QRY_TYPE": qryType,
        "LOGIN_PARTY_CD": loginPartyCd,
        "USER_TYPE": userType,
        "id": id,
        "IMP_DT_TM": impDtTm,
        "EXTR_FLTR1": extrFltr1,
        "MOBILENO": mobileno,
        "BLACKLIST": blacklist,
        "START_DATE": startDate,
        "VALID_UPTO": validUpto,
        "firm_user_links": firmUsers,
        "modules": modules,
        "USER_IMAGE_URL": userImageUrl,
        "emailID": email,
      };
}

class Payload {
  Pagination pagination;

  Payload({
    required this.pagination,
  });

  factory Payload.fromJson(Map<String, dynamic> json) => Payload(
        pagination: Pagination.fromJson(json["pagination"]),
      );

  Map<String, dynamic> toJson() => {
        "pagination": pagination.toJson(),
      };
}

class Pagination {
  dynamic itemsPerPage;
  dynamic page;
  dynamic total;
  List<Link> links;
  dynamic lastPage;
  dynamic from;
  dynamic to;

  Pagination({
    required this.itemsPerPage,
    required this.page,
    required this.total,
    required this.links,
    required this.lastPage,
    required this.from,
    required this.to,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        itemsPerPage: json["items_per_page"],
        page: json["page"],
        total: json["total"],
        links: List<Link>.from(json["links"].map((x) => Link.fromJson(x))),
        lastPage: json["last_page"],
        from: json["from"],
        to: json["to"],
      );

  Map<String, dynamic> toJson() => {
        "items_per_page": itemsPerPage,
        "page": page,
        "total": total,
        "links": List<dynamic>.from(links.map((x) => x.toJson())),
        "last_page": lastPage,
        "from": from,
        "to": to,
      };
}

class Link {
  bool active;
  dynamic label;
  dynamic page;

  Link({
    required this.active,
    required this.label,
    this.page,
  });

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        active: json["active"],
        label: json["label"],
        page: json["page"],
      );

  Map<String, dynamic> toJson() => {
        "active": active,
        "label": label,
        "page": page,
      };
}
