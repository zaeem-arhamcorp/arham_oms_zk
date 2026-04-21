class AssignIssueRequest {
  final String dealerCd;
  final String issueTitle;
  final String issueDescription;
  final String category;
  final String? dueDate;
  final String priority;
  final String assignDeptCd;
  final String? visitId;

  AssignIssueRequest({
    required this.dealerCd,
    required this.issueTitle,
    required this.issueDescription,
    required this.category,
    this.dueDate,
    required this.priority,
    required this.assignDeptCd,
    this.visitId,
  });

  Map<String, dynamic> toJson() {
    return {
      'dealerCd': dealerCd,
      'issueTitle': issueTitle,
      'issueDescription': issueDescription,
      'category': category,
      'dueDate': dueDate,
      'priority': priority,
      'assignDeptCd': assignDeptCd,
      // visitId is nullable, so don't include it if null
      if (visitId != null) 'visitId': visitId,
    };
  }

  factory AssignIssueRequest.fromJson(Map<String, dynamic> json) {
    return AssignIssueRequest(
      dealerCd: json['dealerCd'] ?? '',
      issueTitle: json['issueTitle'] ?? '',
      issueDescription: json['issueDescription'] ?? '',
      category: json['category'] ?? '',
      dueDate: json['dueDate'],
      priority: json['priority'] ?? '',
      assignDeptCd: json['assignDeptCd'] ?? '',
      visitId: json['visitId'],
    );
  }
}

class AssignIssueResponse {
  final int status;
  final String message;
  final Map<String, dynamic>? data;

  AssignIssueResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory AssignIssueResponse.fromJson(Map<String, dynamic> json) {
    return AssignIssueResponse(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data,
    };
  }
}
