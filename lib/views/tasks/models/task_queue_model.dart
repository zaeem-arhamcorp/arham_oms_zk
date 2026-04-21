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

    // Parse nested department structure and flatten tasks
    for (final dynamic item in dataList) {
      final Map<String, dynamic> deptItem = item as Map<String, dynamic>;
      final String deptCd = deptItem['DEPT_CD'] ?? '';
      final String deptName = deptItem['DEPT_NAME'] ?? '';
      final List<dynamic> tasksInDept = (deptItem['TASKS'] as List<dynamic>?) ??
          (deptItem['tasks'] as List<dynamic>?) ??
          <dynamic>[];

      for (final dynamic taskItem in tasksInDept) {
        final Map<String, dynamic> taskJson = taskItem as Map<String, dynamic>;
        // Add department name to task json before parsing
        taskJson['DEPT_NAME'] = deptName;
        taskJson['DEPT_CD'] = taskJson['DEPT_CD'] ?? deptCd;
        final Task task = Task.fromJson(taskJson);
        flattenedTasks.add(task);
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

  TaskQueueMeta({
    required this.departments,
  });

  factory TaskQueueMeta.fromJson(Map<String, dynamic> json) {
    final List<dynamic> deptList = json['DEPARTMENTS'] as List<dynamic>? ?? [];
    return TaskQueueMeta(
      departments: deptList.map((d) => d.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DEPARTMENTS': departments,
    };
  }
}
