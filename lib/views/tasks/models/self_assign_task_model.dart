class SelfAssignTaskResponse {
  final String message;
  final TaskData data;

  SelfAssignTaskResponse({
    required this.message,
    required this.data,
  });

  factory SelfAssignTaskResponse.fromJson(Map<String, dynamic> json) {
    return SelfAssignTaskResponse(
      message: json['message'] ?? '',
      data: TaskData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'data': data.toJson(),
    };
  }
}

class TaskData {
  final Task task;
  final Assignee assignee;

  TaskData({
    required this.task,
    required this.assignee,
  });

  factory TaskData.fromJson(Map<String, dynamic> json) {
    return TaskData(
      task: Task.fromJson(json['task'] as Map<String, dynamic>),
      assignee: Assignee.fromJson(json['assignee'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task.toJson(),
      'assignee': assignee.toJson(),
    };
  }
}

class Task {
  final String taskId;
  final int taskDbId;
  final String issueId;
  final String? issueTitle;
  final int syncId;
  final String dealerCd;
  final String deptCd;
  final String assigneeUserCd;
  final String? assigneeUserName;
  final String status;
  final String? priority;
  final String? taskStatus;
  final String? dueDate;
  final String? decision;
  final String? decisionNote;
  final String? decisionBy;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<TimelineEntry> timeline;
  final String? taskName;
  final String? deptName;
  final String? stockistName;

  Task({
    required this.taskId,
    required this.taskDbId,
    required this.issueId,
    this.issueTitle,
    required this.syncId,
    required this.dealerCd,
    required this.deptCd,
    required this.assigneeUserCd,
    this.assigneeUserName,
    required this.status,
    this.priority,
    this.taskStatus,
    this.dueDate,
    this.decision,
    this.decisionNote,
    this.decisionBy,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.timeline,
    this.taskName,
    this.deptName,
    this.stockistName,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final List<dynamic> timelineList = json['timeline'] as List<dynamic>? ?? [];
    return Task(
      taskId: json['TASK_ID'] ?? '',
      taskDbId: json['TASK_DB_ID'] ?? 0,
      issueId: json['ISSUE_ID'] ?? '',
      issueTitle: json['ISSUE_TITLE'] ?? json['issue_title'],
      syncId: json['SYNC_ID'] ?? 0,
      dealerCd: json['DEALER_CD'] ?? '',
      deptCd: json['DEPT_CD'] ?? '',
      assigneeUserCd: json['ASSIGNEE_USER_CD'] ?? '',
      assigneeUserName: json['ASSIGNEE_USER_NAME'] ??
          json['ASSIGNEE_NAME'] ??
          json['USER_NAME'] ??
          json['assigneeUserName'] ??
          json['assignee_name'],
      status: json['STATUS'] ?? '',
      priority: json['PRIORITY'] ?? json['priority'],
      taskStatus: json['TASK_STATUS'] ?? json['task_status'],
      dueDate: json['DUE_DATE'],
      decision: json['DECISION'],
      decisionNote: json['DECISION_NOTE'],
      decisionBy: json['DECISION_BY'],
      createdBy: json['CREATED_BY'] ?? '',
      createdAt: json['CREATED_AT'] ?? '',
      updatedAt: json['UPDATED_AT'] ?? '',
      timeline: timelineList
          .map((e) => TimelineEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskName: json['TASK_TITLE'] ??
          json['task_title'] ??
          json['TASK_NAME'] ??
          json['task_name'],
      deptName: json['DEPT_NAME'] ?? json['dept_name'],
      stockistName: json['STOCKIST_NAME'] ??
          json['stockist_name'] ??
          json['DEALER_NAME'] ??
          json['dealer_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'TASK_ID': taskId,
      'TASK_DB_ID': taskDbId,
      'ISSUE_ID': issueId,
      'ISSUE_TITLE': issueTitle,
      'SYNC_ID': syncId,
      'DEALER_CD': dealerCd,
      'DEPT_CD': deptCd,
      'ASSIGNEE_USER_CD': assigneeUserCd,
      'ASSIGNEE_USER_NAME': assigneeUserName,
      'STATUS': status,
      'PRIORITY': priority,
      'TASK_STATUS': taskStatus,
      'DUE_DATE': dueDate,
      'DECISION': decision,
      'DECISION_NOTE': decisionNote,
      'DECISION_BY': decisionBy,
      'CREATED_BY': createdBy,
      'CREATED_AT': createdAt,
      'UPDATED_AT': updatedAt,
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'TASK_NAME': taskName,
      'DEPT_NAME': deptName,
      'STOCKIST_NAME': stockistName,
    };
  }
}

class Assignee {
  final String userCd;
  final String userName;
  final String mobileNo;
  final String userType;
  final String emailId;

  Assignee({
    required this.userCd,
    required this.userName,
    required this.mobileNo,
    required this.userType,
    required this.emailId,
  });

  factory Assignee.fromJson(Map<String, dynamic> json) {
    return Assignee(
      userCd: json['USER_CD'] ?? '',
      userName: json['USER_NAME'] ?? '',
      mobileNo: json['MOBILE_NO'] ?? '',
      userType: json['USER_TYPE'] ?? '',
      emailId: json['EMAIL_ID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'USER_CD': userCd,
      'USER_NAME': userName,
      'MOBILE_NO': mobileNo,
      'USER_TYPE': userType,
      'EMAIL_ID': emailId,
    };
  }
}

class TimelineEntry {
  final String at;
  final String by;
  final String action;
  final String note;

  TimelineEntry({
    required this.at,
    required this.by,
    required this.action,
    required this.note,
  });

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    return TimelineEntry(
      at: json['AT'] ?? '',
      by: json['BY'] ?? '',
      action: json['ACTION'] ?? '',
      note: json['NOTE'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AT': at,
      'BY': by,
      'ACTION': action,
      'NOTE': note,
    };
  }
}
