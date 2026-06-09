class ChildrenModel {
  final String message;
  final List<Data> data;

  ChildrenModel({
    required this.message,
    required this.data,
  });

  factory ChildrenModel.fromJson(Map<String, dynamic> json) {
    return ChildrenModel(
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => Data.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'data': data.map((e) => e.toJson()).toList(),
    };
  }
}

class Data {
  final String userCd;
  final String userName;
  final String mobileNo;
  final String userType;
  final String? parentUser;
  final String? userImageUrl;
  final String? emailId;
  final String? parentUserName;
  final bool isMaster;
  final bool webAccess;
  final bool isParent;
  final int childrenCount;
  final bool isSelf;
  final bool isDeactivated;
  final String userStatus;
  final String? lastPunchIn;
  final String? lastPunchOut;
  final String? tripStatus;
  final int? tripId;
  final String? gpsSource;
  final double? lat;
  final double? long;
  final String? lastGpsAt;

  Data({
    required this.userCd,
    required this.userName,
    required this.mobileNo,
    required this.userType,
    this.parentUser,
    this.userImageUrl,
    this.emailId,
    this.parentUserName,
    required this.isMaster,
    required this.webAccess,
    required this.isParent,
    required this.childrenCount,
    required this.isSelf,
    required this.isDeactivated,
    required this.userStatus,
    this.lastPunchIn,
    this.lastPunchOut,
    this.tripStatus,
    this.tripId,
    this.gpsSource,
    this.lat,
    this.long,
    this.lastGpsAt,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      userCd: json['USER_CD']?.toString() ?? '',
      userName: json['USER_NAME']?.toString() ?? '',
      mobileNo: json['MOBILENO']?.toString() ?? '',
      userType: json['USER_TYPE']?.toString() ?? '',
      parentUser: json['PARENT_USER']?.toString(),
      userImageUrl: json['USER_IMAGE_URL']?.toString(),
      emailId: json['EMAIL_ID']?.toString(),
      parentUserName: json['PARENT_USER_NAME']?.toString(),
      isMaster: json['IS_MASTER'] ?? false,
      webAccess: json['WEB_ACCESS'] ?? false,
      isParent: json['IS_PARENT'] ?? false,
      childrenCount: json['CHILDREN_COUNT'] ?? 0,
      isSelf: json['IS_SELF'] ?? false,
      isDeactivated: json['IS_DEACTIVATED'] ?? false,
      userStatus: json['USER_STATUS']?.toString() ?? '',
      lastPunchIn: json['LASTPUNCH_IN']?.toString(),
      lastPunchOut: json['LASTPUNCH_OUT']?.toString(),
      tripStatus: json['TRIP_STATUS']?.toString(),
      tripId: json['TRIP_ID'],
      gpsSource: json['GPS_SOURCE']?.toString(),
      lat: json['LAT'] == null ? null : (json['LAT'] as num).toDouble(),
      long: json['LONG'] == null ? null : (json['LONG'] as num).toDouble(),
      lastGpsAt: json['LASTGPSAT']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'USER_CD': userCd,
      'USER_NAME': userName,
      'MOBILENO': mobileNo,
      'USER_TYPE': userType,
      'PARENT_USER': parentUser,
      'USER_IMAGE_URL': userImageUrl,
      'EMAIL_ID': emailId,
      'PARENT_USER_NAME': parentUserName,
      'IS_MASTER': isMaster,
      'WEB_ACCESS': webAccess,
      'IS_PARENT': isParent,
      'CHILDREN_COUNT': childrenCount,
      'IS_SELF': isSelf,
      'IS_DEACTIVATED': isDeactivated,
      'USER_STATUS': userStatus,
      'LASTPUNCH_IN': lastPunchIn,
      'LASTPUNCH_OUT': lastPunchOut,
      'TRIP_STATUS': tripStatus,
      'TRIP_ID': tripId,
      'GPS_SOURCE': gpsSource,
      'LAT': lat,
      'LONG': long,
      'LASTGPSAT': lastGpsAt,
    };
  }
}
