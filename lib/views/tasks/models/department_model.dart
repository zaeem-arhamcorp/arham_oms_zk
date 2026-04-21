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
  final List<Department>? departments;

  DepartmentData({
    required this.userCd,
    required this.syncId,
    required this.deptCodes,
    this.departments,
  });

  factory DepartmentData.fromJson(Map<String, dynamic> json) {
    // Handle new structure with departments array
    final List<dynamic>? deptList = json['departments'] as List<dynamic>?;
    final List<Department> parsedDepartments = deptList != null
        ? deptList
            .map((e) => Department.fromJson(e as Map<String, dynamic>))
            .toList()
        : [];

    // Extract department codes from either DEPT_CODES or departments array
    final List<String> codes = json['DEPT_CODES'] != null
        ? List<String>.from(json['DEPT_CODES'] as List)
        : parsedDepartments.map((d) => d.deptCd).toList();

    return DepartmentData(
      userCd: json['USER_CD'] ?? '',
      syncId: json['SYNC_ID'] ?? '',
      deptCodes: codes,
      departments: parsedDepartments.isNotEmpty ? parsedDepartments : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'USER_CD': userCd,
      'SYNC_ID': syncId,
      'DEPT_CODES': deptCodes,
      if (departments != null)
        'departments': departments!.map((d) => d.toJson()).toList(),
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
      deptCd: json['DEPT_CD'] ?? '',
      deptName: json['DEPT_NAME'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DEPT_CD': deptCd,
      'DEPT_NAME': deptName,
    };
  }
}
