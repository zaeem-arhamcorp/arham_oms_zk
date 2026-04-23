import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/views/tasks/models/stockist_model.dart';
import 'package:arham_corporation/views/tasks/models/department_model.dart';
import 'package:arham_corporation/views/tasks/models/assign_issue_model.dart';
import 'package:arham_corporation/views/tasks/models/hierarchy_user_model.dart';
import 'package:arham_corporation/views/tasks/models/self_assign_task_model.dart';
import 'package:arham_corporation/views/tasks/models/task_detail_model.dart';
import 'package:arham_corporation/views/tasks/models/task_queue_model.dart';
import 'package:flutter/foundation.dart';

class TaskApiService {
  static const String _contentType = 'application/json';

  static void _log(String message) {
    debugPrint('[TaskApiService] $message');
  }

  /// Fetch stockists from products/party?groupCd=136
  static Future<StockistResponse> getStockists({required String token}) async {
    try {
      final Uri url = Uri.parse(AppConfig.getStockistsURL);
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return StockistResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch stockists: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getStockists error: $e');
      throw Exception('Error fetching stockists: $e');
    }
  }

  /// Fetch departments for current user from my-departments
  static Future<DepartmentResponse> getMyDepartments(
      {required String token}) async {
    try {
      final Uri url = Uri.parse(AppConfig.getMyDepartmentsURL);
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return DepartmentResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch departments: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getMyDepartments error: $e');
      throw Exception('Error fetching departments: $e');
    }
  }

  /// Fetch hierarchy users for current user from dealer-flow/users/hierarchy
  static Future<HierarchyUsersResponse> getHierarchyUsers({
    required String token,
  }) async {
    try {
      final Uri url = Uri.parse(AppConfig.hierarchyUsersURL);
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return HierarchyUsersResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch hierarchy users: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getHierarchyUsers error: $e');
      throw Exception('Error fetching hierarchy users: $e');
    }
  }

  /// Submit an issue to dealer-flow/issues
  static Future<AssignIssueResponse> assignIssue({
    required String token,
    required AssignIssueRequest request,
  }) async {
    try {
      final Uri url = Uri.parse(AppConfig.assignIssueURL);
      final Map<String, String> headers = <String, String>{
        'Content-Type': _contentType,
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };
      final String requestBody = jsonEncode(request.toJson());

      _log('POST URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');
      _log('POST request body: $requestBody');

      final http.Response response = await http
          .post(
            url,
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      _log('POST response status: ${response.statusCode}');
      _log('POST response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return AssignIssueResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to assign issue: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('assignIssue error: $e');
      throw Exception('Error assigning issue: $e');
    }
  }

  /// Self-assign a task to current user via PATCH dealer-flow/tasks/{taskId}/self-assign
  static Future<SelfAssignTaskResponse> selfAssignTask({
    required String token,
    required String taskId,
    String? userCd,
  }) async {
    try {
      final String url =
          '${AppConfig.baseURL}dealer-flow/tasks/$taskId/self-assign';
      final Uri uri = Uri.parse(url);
      final Map<String, String> headers = <String, String>{
        'Content-Type': _contentType,
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('PATCH URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      String? requestBody;
      if (userCd != null && userCd.trim().isNotEmpty) {
        final String normalizedUserCd = userCd.trim();
        final int? parsedUserCd = int.tryParse(normalizedUserCd);
        final dynamic userCdValue = parsedUserCd ?? normalizedUserCd;
        requestBody = jsonEncode(<String, dynamic>{
          'user_cd': userCdValue,
        });
        _log('PATCH request body: $requestBody');
      }

      final http.Response response = await http
          .patch(
            uri,
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      _log('PATCH response status: ${response.statusCode}');
      _log('PATCH response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return SelfAssignTaskResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to self-assign task: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('selfAssignTask error: $e');
      throw Exception('Error self-assigning task: $e');
    }
  }

  /// Update task workflow status via PATCH dealer-flow/tasks/{taskId}/status
  static Future<void> updateTaskStatus({
    required String token,
    required String taskId,
    required String status,
    required String note,
  }) async {
    try {
      final Uri url =
          Uri.parse('${AppConfig.baseURL}dealer-flow/tasks/$taskId/status');
      final Map<String, String> headers = <String, String>{
        'Content-Type': _contentType,
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };
      final String requestBody = jsonEncode(<String, String>{
        'status': status,
        'note': note,
      });

      _log('PATCH URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');
      _log('PATCH request body: $requestBody');

      final http.Response response = await http
          .patch(
            url,
            headers: headers,
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      _log('PATCH response status: ${response.statusCode}');
      _log('PATCH response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to update task status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('updateTaskStatus error: $e');
      throw Exception('Error updating task status: $e');
    }
  }

  /// Fetch department task queue from dealer-flow/departments/tasks/queue (without deptCd parameter)
  static Future<TaskQueueResponse> getDepartmentTaskQueue({
    required String token,
    String? deptCd,
    String? status,
    String? priority,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final Uri baseUri =
          Uri.parse('${AppConfig.baseURL}dealer-flow/departments/tasks/queue');
      final Map<String, String> queryParams = <String, String>{};
      if (deptCd != null && deptCd.isNotEmpty) {
        queryParams['deptCd'] = deptCd;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final Uri uri = queryParams.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParams);
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $uri');
      _log('GET query params: $queryParams');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return TaskQueueResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch task queue: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getDepartmentTaskQueue error: $e');
      throw Exception('Error fetching task queue: $e');
    }
  }

  /// Fetch current user and children tasks from dealer-flow/users/hierarchy/tasks
  static Future<TaskQueueResponse> getHierarchyUserTasks({
    required String token,
    String? status,
    String? priority,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final Uri baseUri = Uri.parse(AppConfig.hierarchyTasksURL);
      final Map<String, String> queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final Uri uri = queryParams.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParams);
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $uri');
      _log('GET query params: $queryParams');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return TaskQueueResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch hierarchy user tasks: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getHierarchyUserTasks error: $e');
      throw Exception('Error fetching hierarchy user tasks: $e');
    }
  }

  /// Fetch issue details for a selected task/issue via dealer-flow/issues/{issueId}
  static Future<TaskDetailResponse> getIssueDetails({
    required String token,
    required String issueId,
  }) async {
    try {
      final Uri url =
          Uri.parse('${AppConfig.baseURL}dealer-flow/issues/$issueId');
      final Map<String, String> headers = <String, String>{
        'x-app-type': 'oms',
        'Authorization': 'Bearer $token',
      };

      _log('GET URL: $url');
      _log('Current token param: $token');
      _log('Token passed in Authorization header: ${headers['Authorization']}');

      final http.Response response = await http
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      _log('GET response status: ${response.statusCode}');
      _log('GET response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(response.body) as Map<String, dynamic>;
        return TaskDetailResponse.fromJson(jsonResponse);
      } else {
        throw Exception(
          'Failed to fetch issue details: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      _log('getIssueDetails error: $e');
      throw Exception('Error fetching issue details: $e');
    }
  }
}
