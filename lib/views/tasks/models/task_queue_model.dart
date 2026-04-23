import 'package:arham_corporation/views/tasks/models/self_assign_task_model.dart';

class TaskQueueResponse {
  final String message;
  final List<Task> data;
  final TaskQueueMeta meta;

  TaskQueueResponse({
    required this.message,
    required this.data,
    required this.meta,
  });

  factory TaskQueueResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dataList = json['data'] as List<dynamic>? ?? [];
    final List<Task> flattenedTasks = <Task>[];

    // Supports both:
    // 1) Nested department structure with TASKS array.
    // 2) Flat task array returned by hierarchy tasks API.
    for (final dynamic item in dataList) {
      final Map<String, dynamic> dataItem = item as Map<String, dynamic>;
      final List<dynamic> tasksInDept = (dataItem['TASKS'] as List<dynamic>?) ??
          (dataItem['tasks'] as List<dynamic>?) ??
          <dynamic>[];

      if (tasksInDept.isNotEmpty) {
        final String deptCd = dataItem['DEPT_CD'] ?? '';
        final String deptName = dataItem['DEPT_NAME'] ?? '';
        for (final dynamic taskItem in tasksInDept) {
          final Map<String, dynamic> taskJson =
              taskItem as Map<String, dynamic>;
          // Add department name to task json before parsing.
          taskJson['DEPT_NAME'] = taskJson['DEPT_NAME'] ?? deptName;
          taskJson['DEPT_CD'] = taskJson['DEPT_CD'] ?? deptCd;
          final Task task = Task.fromJson(taskJson);
          flattenedTasks.add(task);
        }
      } else {
        // Flat task object case.
        flattenedTasks.add(Task.fromJson(dataItem));
      }
    }

    return TaskQueueResponse(
      message: json['message'] ?? '',
      data: flattenedTasks,
      meta: TaskQueueMeta.fromJson(json['meta'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'data': data.map((t) => t.toJson()).toList(),
      'meta': meta.toJson(),
    };
  }
}

class TaskQueueMeta {
  final List<String> departments;
  final int? totalUsers;
  final int? totalTasks;
  final String? rootUserCd;

  TaskQueueMeta({
    required this.departments,
    this.totalUsers,
    this.totalTasks,
    this.rootUserCd,
  });

  factory TaskQueueMeta.fromJson(Map<String, dynamic> json) {
    final List<dynamic> deptList = json['DEPARTMENTS'] as List<dynamic>? ?? [];
    return TaskQueueMeta(
      departments: deptList.map((d) => d.toString()).toList(),
      totalUsers: int.tryParse((json['TOTAL_USERS'] ?? '').toString()),
      totalTasks: int.tryParse((json['TOTAL_TASKS'] ?? '').toString()),
      rootUserCd: json['ROOT_USER_CD']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DEPARTMENTS': departments,
      if (totalUsers != null) 'TOTAL_USERS': totalUsers,
      if (totalTasks != null) 'TOTAL_TASKS': totalTasks,
      if (rootUserCd != null) 'ROOT_USER_CD': rootUserCd,
    };
  }
}
