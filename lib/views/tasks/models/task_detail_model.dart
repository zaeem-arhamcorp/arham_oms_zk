import 'package:arham_corporation/views/tasks/models/self_assign_task_model.dart';

class TaskDetailResponse {
  final String message;
  final IssueDetailData data;

  TaskDetailResponse({
    required this.message,
    required this.data,
  });

  factory TaskDetailResponse.fromJson(Map<String, dynamic> json) {
    return TaskDetailResponse(
      message: json['message'] ?? '',
      data: IssueDetailData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'data': data.toJson(),
    };
  }
}

class IssueDetailData {
  final String issueId;
  final int syncId;
  final String dealerCd;
  final String visitId;
  final String issueTitle;
  final String issueDescription;
  final String category;
  final String priority;
  final String source;
  final String createdBySr;
  final List<String> assignedDeptCds;
  final String assignedDeptCd;
  final String assignedToUserCd;
  final String status;
  final String? lastDecision;
  final String? decisionBy;
  final String createdAt;
  final String updatedAt;
  final List<IssueTimelineEntry> timeline;
  final List<Task> tasks;

  IssueDetailData({
    required this.issueId,
    required this.syncId,
    required this.dealerCd,
    required this.visitId,
    required this.issueTitle,
    required this.issueDescription,
    required this.category,
    required this.priority,
    required this.source,
    required this.createdBySr,
    required this.assignedDeptCds,
    required this.assignedDeptCd,
    required this.assignedToUserCd,
    required this.status,
    this.lastDecision,
    this.decisionBy,
    required this.createdAt,
    required this.updatedAt,
    required this.timeline,
    required this.tasks,
  });

  factory IssueDetailData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> timelineList = json['timeline'] as List<dynamic>? ?? [];
    final List<dynamic> taskList = (json['tasks'] as List<dynamic>?) ??
        (json['TASKS'] as List<dynamic>?) ??
        <dynamic>[];

    return IssueDetailData(
      issueId: json['ISSUE_ID'] ?? '',
      syncId: json['SYNC_ID'] ?? 0,
      dealerCd: json['DEALER_CD'] ?? '',
      visitId: json['VISIT_ID'] ?? '',
      issueTitle: json['ISSUE_TITLE'] ?? '',
      issueDescription: json['ISSUE_DESCRIPTION'] ?? '',
      category: json['CATEGORY'] ?? '',
      priority: json['PRIORITY'] ?? '',
      source: json['SOURCE'] ?? '',
      createdBySr: json['CREATED_BY_SR'] ?? '',
      assignedDeptCds:
          (json['ASSIGNED_DEPT_CDS'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      assignedDeptCd: json['ASSIGNED_DEPT_CD'] ?? '',
      assignedToUserCd: json['ASSIGNED_TO_USER_CD'] ?? '',
      status: json['STATUS'] ?? '',
      lastDecision: json['LAST_DECISION'],
      decisionBy: json['DECISION_BY'],
      createdAt: json['CREATED_AT'] ?? '',
      updatedAt: json['UPDATED_AT'] ?? '',
      timeline: timelineList
          .map((dynamic item) => IssueTimelineEntry.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(),
      tasks: taskList
          .map((dynamic item) => Task.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ISSUE_ID': issueId,
      'SYNC_ID': syncId,
      'DEALER_CD': dealerCd,
      'VISIT_ID': visitId,
      'ISSUE_TITLE': issueTitle,
      'ISSUE_DESCRIPTION': issueDescription,
      'CATEGORY': category,
      'PRIORITY': priority,
      'SOURCE': source,
      'CREATED_BY_SR': createdBySr,
      'ASSIGNED_DEPT_CDS': assignedDeptCds,
      'ASSIGNED_DEPT_CD': assignedDeptCd,
      'ASSIGNED_TO_USER_CD': assignedToUserCd,
      'STATUS': status,
      'LAST_DECISION': lastDecision,
      'DECISION_BY': decisionBy,
      'CREATED_AT': createdAt,
      'UPDATED_AT': updatedAt,
      'timeline':
          timeline.map((IssueTimelineEntry entry) => entry.toJson()).toList(),
      'tasks': tasks.map((Task task) => task.toJson()).toList(),
    };
  }
}

class IssueTimelineEntry {
  final String at;
  final String by;
  final String action;
  final String note;

  IssueTimelineEntry({
    required this.at,
    required this.by,
    required this.action,
    required this.note,
  });

  factory IssueTimelineEntry.fromJson(Map<String, dynamic> json) {
    return IssueTimelineEntry(
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
