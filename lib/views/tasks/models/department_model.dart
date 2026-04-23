class DepartmentResponse {
  final bool status;
  final String message;
  final DepartmentData data;

  DepartmentResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory DepartmentResponse.fromJson(Map<String, dynamic> json) {
    return DepartmentResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data: DepartmentData.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.toJson(),
    };
  }
}

class DepartmentData {
  final String userCd;
  final String syncId;
  final List<String> deptCodes;
  final List<Department> departments;

  DepartmentData({
    required this.userCd,
    required this.syncId,
    required this.deptCodes,
    required this.departments,
  });

  factory DepartmentData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> deptList =
        (json['departments'] ?? json['DEPARTMENTS']) as List<dynamic>? ??
            <dynamic>[];
    final List<Department> parsedDepartments = deptList
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => Department.fromJson(e))
        .toList();

    final List<dynamic> rawCodes =
        (json['DEPT_CODES'] ?? json['deptCodes']) as List<dynamic>? ??
            <dynamic>[];
    final List<String> codesFromPayload = rawCodes
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    final List<String> codes = codesFromPayload.isNotEmpty
        ? codesFromPayload
        : parsedDepartments.map((Department d) => d.deptCd).toList();

    return DepartmentData(
      userCd: (json['USER_CD'] ?? json['userCd'] ?? '').toString(),
      syncId: (json['SYNC_ID'] ?? json['syncId'] ?? '').toString(),
      deptCodes: codes,
      departments: parsedDepartments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'USER_CD': userCd,
      'SYNC_ID': syncId,
      'DEPT_CODES': deptCodes,
      'departments': departments.map((Department d) => d.toJson()).toList(),
    };
  }
}

class Department {
  final String deptCd;
  final String deptName;

  Department({
    required this.deptCd,
    required this.deptName,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      deptCd: (json['DEPT_CD'] ?? json['deptCd'] ?? '').toString(),
      deptName: (json['DEPT_NAME'] ?? json['deptName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DEPT_CD': deptCd,
      'DEPT_NAME': deptName,
    };
  }
}
