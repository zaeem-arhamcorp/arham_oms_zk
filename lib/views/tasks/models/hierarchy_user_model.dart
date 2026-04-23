class HierarchyUsersResponse {
  final String message;
  final List<HierarchyUser> data;
  final HierarchyUsersMeta meta;

  HierarchyUsersResponse({
    required this.message,
    required this.data,
    required this.meta,
  });

  factory HierarchyUsersResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawData = json['data'] as List<dynamic>? ?? <dynamic>[];
    return HierarchyUsersResponse(
      message: (json['message'] ?? '').toString(),
      data: rawData
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => HierarchyUser.fromJson(e))
          .toList(),
      meta: HierarchyUsersMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class HierarchyUser {
  final String userCd;
  final String userName;
  final String userType;
  final String parentUser;
  final String mobileNo;
  final String emailId;
  final int level;

  HierarchyUser({
    required this.userCd,
    required this.userName,
    required this.userType,
    required this.parentUser,
    required this.mobileNo,
    required this.emailId,
    required this.level,
  });

  factory HierarchyUser.fromJson(Map<String, dynamic> json) {
    return HierarchyUser(
      userCd: (json['USER_CD'] ?? '').toString(),
      userName: (json['USER_NAME'] ?? '').toString(),
      userType: (json['USER_TYPE'] ?? '').toString(),
      parentUser: (json['PARENT_USER'] ?? '').toString(),
      mobileNo: (json['MOBILENO'] ?? '').toString(),
      emailId: (json['EMAIL_ID'] ?? '').toString(),
      level: int.tryParse((json['LEVEL'] ?? 0).toString()) ?? 0,
    );
  }
}

class HierarchyUsersMeta {
  final String rootUserCd;
  final int totalUsers;

  HierarchyUsersMeta({
    required this.rootUserCd,
    required this.totalUsers,
  });

  factory HierarchyUsersMeta.fromJson(Map<String, dynamic> json) {
    return HierarchyUsersMeta(
      rootUserCd: (json['ROOT_USER_CD'] ?? '').toString(),
      totalUsers: int.tryParse((json['TOTAL_USERS'] ?? 0).toString()) ?? 0,
    );
  }
}
