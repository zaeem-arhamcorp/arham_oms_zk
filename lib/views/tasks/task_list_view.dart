import 'dart:io';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/tasks/models/department_model.dart';
import 'package:arham_corporation/views/tasks/models/hierarchy_user_model.dart';
import 'package:arham_corporation/views/tasks/models/self_assign_task_model.dart';
import 'package:arham_corporation/views/tasks/models/stockist_model.dart';
import 'package:arham_corporation/views/tasks/models/task_queue_model.dart';
import 'package:arham_corporation/views/tasks/services/api_service.dart';
import 'package:arham_corporation/views/tasks/task_detail_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/constants.dart';

class TaskListView extends StatefulWidget {
  const TaskListView({super.key});

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  bool _isLoading = true;
  List<Task> _tasks = <Task>[];
  String? _errorMessage;
  String _currentUserCd = '';
  String? _selectedDeptCd;
  List<String> _availableDeptCds = <String>[];

  // Mapping for dealer/department enrichment
  Map<String, String> _dealerNameMap = <String, String>{};
  Map<String, String> _deptNameMap = <String, String>{};

  // Filter state variables
  String? _filterUser;
  String? _filterFromDate;
  String? _filterToDate;
  String? _filterStockist;
  String? _filterDepartment;
  String? _filterStatus;
  String? _filterPriority;

  void _logDebug(String message) {
    debugPrint('[TaskListView] $message');
  }

  @override
  void initState() {
    super.initState();
    _fetchDepartmentsAndTasks();
  }

  Future<void> _onRefresh() async {
    await _fetchDepartmentTasks();
  }

  String getErrorMessage(dynamic e) {
    return (e is SocketException || e.toString().contains('SocketException'))
        ? Constants.networkMsg
        : "Something went wrong";
  }

  Future<void> _fetchDepartmentsAndTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;
      final SharedPreferences sp = await SharedPreferences.getInstance();
      _currentUserCd = sp.getString('UserCode') ?? '';
      _logDebug('Current user code: $_currentUserCd');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Fetch departments and build dept name map
      _logDebug('Calling getMyDepartments API');
      final DepartmentResponse deptResponse =
          await TaskApiService.getMyDepartments(token: token);
      _logDebug(
          'getMyDepartments response: departments=${deptResponse.data.deptCodes.length}');

      _deptNameMap = <String, String>{};
      for (final Department dept in deptResponse.data.departments) {
        _deptNameMap[dept.deptCd] = dept.deptName;
      }

      // Extract department codes
      _availableDeptCds = deptResponse.data.deptCodes;

      if (_availableDeptCds.isEmpty) {
        throw Exception('No departments assigned to this user.');
      }

      // Use first department code
      _selectedDeptCd = _availableDeptCds.first;

      // Fetch stockists and build dealer name map
      _logDebug('Calling getStockists API');
      final StockistResponse stockistResponse =
          await TaskApiService.getStockists(token: token);
      _logDebug(
          'getStockists response: stockists=${stockistResponse.data.length}');

      _dealerNameMap = <String, String>{};
      for (final Stockist stockist in stockistResponse.data) {
        _dealerNameMap[stockist.accCd] = stockist.accName;
      }

      // Now fetch tasks without deptCd parameter
      await _fetchDepartmentTasks();
    } catch (e) {
      setState(() {
        final isNetworkError =
            e is SocketException || e.toString().contains('SocketException');

        _errorMessage =
            isNetworkError ? Constants.networkMsg : 'Error loading data';
        _isLoading = false;
      });
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text(_errorMessage ?? Constants.networkMsg)));
        AppSnackBar.showGetXCustomSnackBar(
          message: _errorMessage ?? Constants.networkMsg,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _fetchDepartmentTasks({
    String? status,
    String? priority,
    String? fromDate,
    String? toDate,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Fetch current user + hierarchy tasks.
      _logDebug(
          'Calling getHierarchyUserTasks API with status=${status ?? _filterStatus} priority=${priority ?? _filterPriority} fromDate=${fromDate ?? _filterFromDate} toDate=${toDate ?? _filterToDate}');
      final TaskQueueResponse response =
          await TaskApiService.getHierarchyUserTasks(
        token: token,
        status: status ?? _filterStatus,
        priority: priority ?? _filterPriority,
        fromDate: fromDate ?? _filterFromDate,
        toDate: toDate ?? _filterToDate,
      );
      _logDebug(
          'getHierarchyUserTasks response: tasks=${response.data.length}');

      // Enrich tasks with stockist names and department names
      final List<Task> enrichedTasks = <Task>[];
      for (final Task task in response.data) {
        enrichedTasks.add(
          Task(
            taskId: task.taskId,
            taskDbId: task.taskDbId,
            issueId: task.issueId,
            issueTitle: task.issueTitle,
            syncId: task.syncId,
            dealerCd: task.dealerCd,
            deptCd: task.deptCd,
            assigneeUserCd: task.assigneeUserCd,
            assigneeUserName: task.assigneeUserName,
            status: task.status,
            priority: task.priority,
            taskStatus: task.taskStatus,
            dueDate: task.dueDate,
            decision: task.decision,
            decisionNote: task.decisionNote,
            decisionBy: task.decisionBy,
            createdBy: task.createdBy,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            timeline: task.timeline,
            taskName: task.taskName,
            deptName: _deptNameMap[task.deptCd] ?? task.deptCd,
            stockistName: _dealerNameMap[task.dealerCd] ?? task.dealerCd,
          ),
        );
      }

      setState(() {
        _tasks = enrichedTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading tasks: $e';
        _isLoading = false;
      });
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(getErrorMessage(e))),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: getErrorMessage(e),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<List<HierarchyUser>> _fetchAssignableHierarchyUsers() async {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    final String? token = userProvider.token;

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please login again.');
    }

    _logDebug('Calling getHierarchyUsers API for assignable users list');
    final HierarchyUsersResponse response =
        await TaskApiService.getHierarchyUsers(token: token);

    final Map<String, HierarchyUser> uniqueUsers = <String, HierarchyUser>{};
    for (final HierarchyUser user in response.data) {
      final String key = user.userCd.trim();
      if (key.isNotEmpty) {
        uniqueUsers[key] = user;
      }
    }

    final List<HierarchyUser> assignableUsers = uniqueUsers.values.toList()
      ..sort((HierarchyUser a, HierarchyUser b) {
        if (a.level != b.level) {
          return a.level.compareTo(b.level);
        }
        return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
      });

    _logDebug('Hierarchy assignable users count: ${assignableUsers.length}');
    return assignableUsers;
  }

  Future<void> _assignTaskToSelectedUser({
    required Task task,
    required HierarchyUser selectedUser,
  }) async {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    final String? token = userProvider.token;

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found. Please login again.');
    }

    final SelfAssignTaskResponse response = await TaskApiService.selfAssignTask(
      token: token,
      taskId: task.taskId,
      userCd: selectedUser.userCd,
    );
    _logDebug(
      'selfAssignTask response for user ${selectedUser.userCd}: ${response.message}',
    );

    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(response.message),
      //     backgroundColor: Colors.green,
      //   ),
      // );
      AppSnackBar.showGetXCustomSnackBar(
        message: response.message,
        backgroundColor: Colors.green,
      );
    }

    await _fetchDepartmentTasks();
  }

  Future<void> _showAssignTaskDialog(Task task) async {
    try {
      final List<HierarchyUser> assignableUsers =
          await _fetchAssignableHierarchyUsers();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Assign Task'),
            content: SizedBox(
              width: double.maxFinite,
              child: assignableUsers.isEmpty
                  ? const Text('No users found')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: assignableUsers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final HierarchyUser selectedUser =
                            assignableUsers[index];
                        final bool isSelf = _normalize(selectedUser.userCd) ==
                            _normalize(_currentUserCd);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isSelf
                                ? '${selectedUser.userName} (You)'
                                : selectedUser.userName,
                          ),
                          subtitle: Text('User Code: ${selectedUser.userCd}'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            try {
                              await _assignTaskToSelectedUser(
                                task: task,
                                selectedUser: selectedUser,
                              );
                            } catch (e) {
                              if (!mounted) {
                                return;
                              }
                              // ScaffoldMessenger.of(this.context).showSnackBar(
                              //   SnackBar(
                              //     content: Text('Error assigning task: $e'),
                              //     backgroundColor: Colors.red,
                              //   ),
                              // );
                              AppSnackBar.showGetXCustomSnackBar(
                                message: 'Error assigning task: $e',
                                backgroundColor: Colors.red,
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Unable to load child users: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Unable to load child users: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  String _normalize(String? value) => (value ?? '').trim();

  String _taskWorkflowStatus(Task task) {
    final String derived = _normalize(task.taskStatus).toUpperCase();
    if (derived.isNotEmpty) {
      return derived;
    }
    return _normalize(task.status).toUpperCase();
  }

  bool _isAssigned(Task task) {
    final String assigneeCd = _normalize(task.assigneeUserCd);
    return assigneeCd.isNotEmpty && assigneeCd.toLowerCase() != 'null';
  }

  bool _isAssignedToCurrentUser(Task task) {
    if (!_isAssigned(task)) {
      return false;
    }
    return _normalize(task.assigneeUserCd) == _normalize(_currentUserCd);
  }

  bool _isTaskCreator(Task task) {
    return _normalize(task.createdBy) == _normalize(_currentUserCd);
  }

  String _assigneeLabel(Task task) {
    if (!_isAssigned(task)) {
      return 'Unassigned';
    }
    final String assigneeName = _normalize(task.assigneeUserName);
    if (assigneeName.isNotEmpty && assigneeName.toLowerCase() != 'null') {
      return assigneeName;
    }
    return _normalize(task.assigneeUserCd);
  }

  String _priorityLabel(Task task) {
    final String priority = _normalize(task.priority);
    return priority.isNotEmpty ? priority.toUpperCase() : 'NORMAL';
  }

  String _formatTaskDate(String dateTime) {
    final String raw = dateTime.split('T').first;
    final List<String> parts = raw.split('-');
    if (parts.length != 3) {
      return raw;
    }
    return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
  }

  DateTime? _tryParseYmd(String value) {
    try {
      final List<String> parts = value.split('-');
      if (parts.length != 3) {
        return null;
      }
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isDateWithinRange({
    required String taskDate,
    String? fromDate,
    String? toDate,
  }) {
    if (fromDate == null && toDate == null) {
      return true;
    }

    final DateTime? taskDt = _tryParseYmd(taskDate);
    if (taskDt == null) {
      return false;
    }

    if (fromDate != null) {
      final DateTime? fromDt = _tryParseYmd(fromDate);
      if (fromDt != null && taskDt.isBefore(fromDt)) {
        return false;
      }
    }

    if (toDate != null) {
      final DateTime? toDt = _tryParseYmd(toDate);
      if (toDt != null && taskDt.isAfter(toDt)) {
        return false;
      }
    }

    return true;
  }

  List<Task> _applyFilters({
    required List<Task> source,
    String? user,
    String? fromDate,
    String? toDate,
    String? stockist,
    String? department,
    String? status,
    String? priority,
  }) {
    return source.where((Task task) {
      final String taskUser = _assigneeLabel(task);
      final String taskDate = _formatTaskDate(task.updatedAt);
      final String taskStockist =
          _normalize(task.stockistName ?? task.dealerCd);
      final String taskDepartment = _normalize(task.deptName ?? task.deptCd);
      final String taskStatus = task.status.toUpperCase();
      final String taskPriority = _priorityLabel(task);

      final bool matchesUser = user == null || user == taskUser;
      final bool matchesDate = _isDateWithinRange(
        taskDate: taskDate,
        fromDate: fromDate,
        toDate: toDate,
      );
      final bool matchesStockist = stockist == null || stockist == taskStockist;
      final bool matchesDepartment =
          department == null || department == taskDepartment;
      final bool matchesStatus = status == null || status == taskStatus;
      final bool matchesPriority = priority == null || priority == taskPriority;

      return matchesUser &&
          matchesDate &&
          matchesStockist &&
          matchesDepartment &&
          matchesStatus &&
          matchesPriority;
    }).toList();
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final List<String> result = values
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  List<Task> get _filteredTasks => _applyFilters(
        source: _tasks,
        user: _filterUser,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
        stockist: _filterStockist,
        department: _filterDepartment,
        status: _filterStatus,
        priority: _filterPriority,
      );

  @override
  Widget build(BuildContext context) {
    final List<Task> visibleTasks = _filteredTasks;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF245B87),
                Color(0xFF1B3F6B),
              ],
            ),
          ),
        ),
        title: Text(
          'Department Queue',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _onRefresh,
                child: _errorMessage != null
                    ? RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Color(0xFF9B2C32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4A5261),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => _fetchDepartmentTasks(),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF245B87),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: visibleTasks.isEmpty
                            ? SingleChildScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.inbox_outlined,
                                        size: 48,
                                        color: Color(0xFF8C93A2),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No tasks available',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF4A5261),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(18, 16, 18, 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      'Manage incoming dealer support requests.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.35,
                                        color: Color(0xFF4A5261),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // _buildSortRow(),
                                    // const SizedBox(height: 16),
                                    ...visibleTasks.map(_buildTaskCard),
                                    // if (visibleTasks.length >= 5) _buildMoreQueueCard(),
                                  ],
                                ),
                              ),
                      ),
              ),
      ),
    );
  }

  void _showFilterDialog() {
    String? localFilterUser = _filterUser;
    String? localFilterFromDate = _filterFromDate;
    String? localFilterToDate = _filterToDate;
    String? localFilterStockist = _filterStockist;
    String? localFilterDepartment = _filterDepartment;
    String? localFilterStatus = _filterStatus;
    String? localFilterPriority = _filterPriority;

    Future<List<String>> loadStockistOptions() async {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final StockistResponse response =
          await TaskApiService.getStockists(token: token);

      return response.data
          .map((Stockist stockist) => stockist.accName)
          .where((String name) => name.trim().isNotEmpty)
          .toList();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setDialogState) {
            final List<Task> previewTasks = _applyFilters(
              source: _tasks,
              user: localFilterUser,
              fromDate: localFilterFromDate,
              toDate: localFilterToDate,
              stockist: localFilterStockist,
              department: localFilterDepartment,
              status: localFilterStatus,
              priority: localFilterPriority,
            );

            final List<Task> userSourceTasks = _applyFilters(
              source: _tasks,
              user: null,
              fromDate: localFilterFromDate,
              toDate: localFilterToDate,
              stockist: localFilterStockist,
              department: localFilterDepartment,
              status: localFilterStatus,
              priority: localFilterPriority,
            );
            final List<Task> stockistSourceTasks = _applyFilters(
              source: _tasks,
              user: localFilterUser,
              fromDate: localFilterFromDate,
              toDate: localFilterToDate,
              stockist: null,
              department: localFilterDepartment,
              status: localFilterStatus,
              priority: localFilterPriority,
            );
            final List<Task> departmentSourceTasks = _applyFilters(
              source: _tasks,
              user: localFilterUser,
              fromDate: localFilterFromDate,
              toDate: localFilterToDate,
              stockist: localFilterStockist,
              department: null,
              status: localFilterStatus,
              priority: localFilterPriority,
            );
            final List<String> userOptions =
                _uniqueSorted(userSourceTasks.map(_assigneeLabel));
            final List<String> stockistOptions = _uniqueSorted(
              stockistSourceTasks.map(
                (Task t) => _normalize(t.stockistName ?? t.dealerCd),
              ),
            );
            final List<String> departmentOptions = _uniqueSorted(
              departmentSourceTasks.map(
                (Task t) => _normalize(t.deptName ?? t.deptCd),
              ),
            );
            const List<String> statusOptions = <String>[
              'PENDING',
              'IN_PROGRESS',
              'COMPLETED',
            ];
            const List<String> priorityOptions = <String>[
              'HIGH',
              'MEDIUM',
              'LOW',
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Text(
                            'Filter Tasks',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF171A22),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF5B6475),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // User Filter
                      _buildFilterLabel('User'),
                      const SizedBox(height: 8),
                      _buildDropdownFilter(
                        value: localFilterUser,
                        items: userOptions,
                        onChanged: (String? value) {
                          setDialogState(() {
                            localFilterUser = value;
                          });
                        },
                        hint: 'Select user',
                      ),
                      const SizedBox(height: 18),
                      // Date Filter
                      _buildFilterLabel('Date Range'),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: DateTime(2023, 1, 1),
                                  maxTime: DateTime(2100, 12, 31),
                                  currentTime: DateTime.now(),
                                  locale: LocaleType.en,
                                  onConfirm: (date) {
                                    setDialogState(() {
                                      localFilterFromDate =
                                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    });
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 48,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9ECF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD1D8E6),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.event,
                                      size: 18,
                                      color: Color(0xFF8892A8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        localFilterFromDate ?? 'From date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: localFilterFromDate != null
                                              ? const Color(0xFF1E232D)
                                              : const Color(0xFF8B94A8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: DateTime(2023, 1, 1),
                                  maxTime: DateTime(2100, 12, 31),
                                  currentTime: DateTime.now(),
                                  locale: LocaleType.en,
                                  onConfirm: (date) {
                                    setDialogState(() {
                                      localFilterToDate =
                                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    });
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 48,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9ECF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD1D8E6),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.event_available,
                                      size: 18,
                                      color: Color(0xFF8892A8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        localFilterToDate ?? 'To date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: localFilterToDate != null
                                              ? const Color(0xFF1E232D)
                                              : const Color(0xFF8B94A8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Stockist Filter
                      _buildFilterLabel('Dealer'),
                      const SizedBox(height: 8),
                      _buildDropdownFilter(
                        value: localFilterStockist,
                        items: stockistOptions,
                        loadItems: loadStockistOptions,
                        onChanged: (String? value) {
                          setDialogState(() {
                            localFilterStockist = value;
                          });
                        },
                        hint: 'Select dealer',
                      ),
                      const SizedBox(height: 18),
                      // Department Filter
                      _buildFilterLabel('Department'),
                      const SizedBox(height: 8),
                      _buildDropdownFilter(
                        value: localFilterDepartment,
                        items: departmentOptions,
                        onChanged: (String? value) {
                          setDialogState(() {
                            localFilterDepartment = value;
                          });
                        },
                        hint: 'Select department',
                      ),
                      const SizedBox(height: 18),
                      // Status Filter
                      _buildFilterLabel('Status'),
                      const SizedBox(height: 8),
                      _buildDropdownFilter(
                        value: localFilterStatus,
                        items: statusOptions,
                        onChanged: (String? value) {
                          setDialogState(() {
                            localFilterStatus = value;
                          });
                        },
                        hint: 'Select status',
                      ),
                      const SizedBox(height: 18),
                      // Priority Filter
                      _buildFilterLabel('Priority'),
                      const SizedBox(height: 8),
                      _buildDropdownFilter(
                        value: localFilterPriority,
                        items: priorityOptions,
                        onChanged: (String? value) {
                          setDialogState(() {
                            localFilterPriority = value;
                          });
                        },
                        hint: 'Select priority',
                      ),
                      const SizedBox(height: 32),
                      // Buttons
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setDialogState(() {
                                  localFilterUser = null;
                                  localFilterFromDate = null;
                                  localFilterToDate = null;
                                  localFilterStockist = null;
                                  localFilterDepartment = null;
                                  localFilterStatus = null;
                                  localFilterPriority = null;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD1D8E6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D667A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                setState(() {
                                  _filterUser = localFilterUser;
                                  _filterFromDate = localFilterFromDate;
                                  _filterToDate = localFilterToDate;
                                  _filterStockist = localFilterStockist;
                                  _filterDepartment = localFilterDepartment;
                                  _filterStatus = localFilterStatus;
                                  _filterPriority = localFilterPriority;
                                });
                                _fetchDepartmentTasks(
                                  status: localFilterStatus,
                                  priority: localFilterPriority,
                                  fromDate: localFilterFromDate,
                                  toDate: localFilterToDate,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245B87),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Color(0xFF636E83),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String? value,
    required List<String> items,
    Future<List<String>> Function()? loadItems,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    return _SearchableDropdownField(
      value: value,
      items: items,
      loadItems: loadItems,
      onChanged: onChanged,
      hint: hint,
    );
  }

  Widget _buildSortRow() {
    return Row(
      children: <Widget>[
        const Text(
          'SORT BY:',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 2.1,
            color: Color(0xFF50586A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'Priority (High to Low)',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF0A3B75),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.keyboard_arrow_down_rounded,
          color: const Color(0xE6394156),
          size: 22,
        ),
      ],
    );
  }

  Widget _buildTaskCard(Task task) {
    // Determine priority color based on status
    Color priorityColor = const Color(0xFFD3E5F8);
    Color priorityTextColor = const Color(0xFF3C6692);
    String priorityText = _priorityLabel(task);
    final String assigneeCd = task.assigneeUserCd.trim();
    final String assigneeName = (task.assigneeUserName ?? '').trim();
    final bool isAssigned =
        assigneeCd.isNotEmpty && assigneeCd.toLowerCase() != 'null';
    final bool isAssignedToCurrentUser = _isAssignedToCurrentUser(task);
    final bool isTaskCreator = _isTaskCreator(task);
    final String workflowStatus = _taskWorkflowStatus(task);
    final bool isCompleted = workflowStatus == 'COMPLETED';
    final bool isInProgress = workflowStatus == 'IN_PROGRESS';
    final String assignmentLabel = isAssigned
        ? (assigneeName.isNotEmpty ? assigneeName : assigneeCd)
        : 'Unassigned';

    String actionLabel = 'ASSIGN TASK';
    VoidCallback? actionHandler = () => _showAssignTaskDialog(task);
    Color actionBgColor = const Color(0xFF235987);

    if (isAssigned) {
      if (isAssignedToCurrentUser) {
        if (isCompleted) {
          actionLabel = 'COMPLETED';
          actionHandler = null;
          actionBgColor = const Color(0xFF5F6B7A);
        } else if (isInProgress) {
          actionLabel = 'COMPLETE TASK';
          actionHandler = () => _handleCompleteTask(task);
          actionBgColor = const Color(0xFF2E7D32);
        } else {
          actionLabel = 'START TASK';
          actionHandler = () => _handleStartTask(task);
          actionBgColor = const Color(0xFFFF9800);
        }
      } else {
        actionLabel = workflowStatus == 'PENDING' ? 'ASSIGNED' : workflowStatus;
        actionHandler = null;
        actionBgColor = const Color(0xFF5F6B7A);
      }
    }

    // if (!isAssigned && isCompleted) {
    //   actionLabel = 'COMPLETED';
    //   actionHandler = null;
    //   actionBgColor = const Color(0xFF5F6B7A);
    // } else if (isAssigned && isInProgress) {
    //   actionLabel = 'IN PROGRESS';
    //   actionHandler = null;
    //   actionBgColor = const Color(0xFF5F6B7A);
    // }
    if (!isAssigned && isCompleted) {
      actionLabel = 'COMPLETED';
      actionHandler = null;
      actionBgColor = const Color(0xFF5F6B7A);
    } else if (isAssigned && isInProgress && !isAssignedToCurrentUser) {
      actionLabel = 'IN PROGRESS';
      actionHandler = null;
      actionBgColor = const Color(0xFF5F6B7A);
    }

    final bool showCreatorReopen = isTaskCreator && isCompleted;

    if (priorityText == 'HIGH') {
      priorityColor = const Color(0xFFE8BCBE);
      priorityTextColor = const Color(0xFF9B2C32);
    } else if (priorityText == 'MEDIUM') {
      priorityColor = const Color(0xFFF8E8BE);
      priorityTextColor = const Color(0xFF8A5B00);
    } else if (priorityText == 'LOW') {
      priorityColor = const Color(0xFFDDEEDB);
      priorityTextColor = const Color(0xFF2D6A42);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) => TaskDetailView(task: task),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        priorityText,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: priorityTextColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      task.updatedAt.split('T').first,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A5062),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  task.taskName ?? task.issueTitle ?? task.taskId,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF161C27),
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${task.deptName ?? task.deptCd}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF083B74),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dealer: ${task.stockistName ?? task.dealerCd}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A5261),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due Date: ${task.dueDate ?? '-'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A5261),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: const Color(0xFFEBEEF4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 15,
                      backgroundColor: Color(0xFFE3E7EE),
                      child: Icon(Icons.person,
                          size: 16, color: Color(0xFF1D212A)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      assignmentLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4A5261),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: actionHandler,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: actionBgColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFB0B8C5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 1,
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showCreatorReopen) ...<Widget>[
                      const SizedBox(width: 10),
                      Builder(
                        builder: (context) {
                          return IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                            ),
                            style: IconButton.styleFrom(
                                side: BorderSide(color: Colors.grey)),
                            onPressed: () async {
                              final RenderBox button =
                                  context.findRenderObject() as RenderBox;
                              final RenderBox overlay = Overlay.of(context)
                                  .context
                                  .findRenderObject() as RenderBox;

                              final Offset position = button.localToGlobal(
                                  Offset.zero,
                                  ancestor: overlay);

                              final selected = await showMenu<String>(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  position.dx, // align left with icon
                                  position.dy +
                                      button.size.height, // BELOW the icon
                                  position.dx + button.size.width,
                                  0,
                                ),
                                items: [
                                  PopupMenuItem<String>(
                                    value: 'reopen',
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    child: const SizedBox(
                                      width: 150,
                                      child: Text(
                                        'Reopen Task',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              if (selected == 'reopen') {
                                _showReopenTaskBottomSheet(task);
                              }
                            },
                          );
                        },
                      ),
                      // SizedBox(
                      //   width: double.infinity,
                      //   height: 40,
                      //   child: OutlinedButton(
                      //     onPressed: () => _handleReopenTask(task),
                      //     style: OutlinedButton.styleFrom(
                      //       foregroundColor: const Color(0xFF2D5F8C),
                      //       side: const BorderSide(color: Color(0xFF2D5F8C)),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(24),
                      //       ),
                      //     ),
                      //     child: const Text(
                      //       'REOPEN TASK',
                      //       style: TextStyle(
                      //         fontSize: 14,
                      //         letterSpacing: 1.4,
                      //         fontWeight: FontWeight.w700,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTakeTask(Task task) async {
    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final SelfAssignTaskResponse response =
          await TaskApiService.selfAssignTask(
        token: token,
        taskId: task.taskId,
      );
      _logDebug('selfAssignTask response: ${response.message}');

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(response.message),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: response.message,
          backgroundColor: Colors.green,
        );

        // Refresh the task list
        _fetchDepartmentTasks();
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Error taking task: $e'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Error taking task: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _handleStartTask(Task task) async {
    await _handleUpdateTaskStatus(
      task: task,
      status: 'IN_PROGRESS',
      note: 'Work started by department user',
      successMessage: 'Task started successfully',
    );
  }

  Future<void> _handleCompleteTask(Task task) async {
    await _showCompleteTaskBottomSheet(task);
  }

  Future<void> _handleReopenTask(
    Task task,
    String note,
  ) async {
    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      await TaskApiService.reopenTask(
        token: token,
        taskId: task.taskId,
      );

      _logDebug('reopenTask response: taskId=${task.taskId}');

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Task reopened successfully'),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Task reopened successfully',
          backgroundColor: Colors.green,
        );
        _fetchDepartmentTasks();
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Error reopening task: $e'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Error reopening task: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _handleUpdateTaskStatus({
    required Task task,
    required String status,
    required String note,
    required String successMessage,
  }) async {
    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      await TaskApiService.updateTaskStatus(
        token: token,
        taskId: task.taskId,
        status: status,
        note: note,
      );
      _logDebug(
          'updateTaskStatus response: taskId=${task.taskId} status=$status note=$note');

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(successMessage),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: successMessage,
          backgroundColor: Colors.green,
        );
        _fetchDepartmentTasks();
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Error updating task status: $e'),
        //     backgroundColor: Colors.red,
        //   ),
        // );
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Error updating task status: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _showCompleteTaskBottomSheet(Task task) async {
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Task',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter completion note',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final String note = noteController.text.trim();

                    if (note.isEmpty) {
                      AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please enter a note',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }

                    Navigator.pop(context);

                    await _handleUpdateTaskStatus(
                      task: task,
                      status: 'COMPLETED',
                      note: note,
                      successMessage: 'Task completed successfully',
                    );
                  },
                  child: const Text(
                    'COMPLETE TASK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReopenTaskBottomSheet(Task task) async {
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reopen Task',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reopen reason',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final String note = noteController.text.trim();

                    if (note.isEmpty) {
                      AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please enter a note',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }

                    Navigator.pop(context);

                    await _handleReopenTask(
                      task,
                      note,
                    );
                  },
                  child: const Text(
                    'REOPEN TASK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreQueueCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD7DCE6),
          width: 1,
        ),
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.work_outline_rounded,
            size: 32,
            color: Color(0xFF8C93A2),
          ),
          SizedBox(height: 12),
          Text(
            '8 more unassigned tasks',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF555D6D),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'LOAD QUEUE',
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 1.7,
              color: Color(0xFF3D6793),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchableDropdownField extends StatefulWidget {
  const _SearchableDropdownField({
    required this.value,
    required this.items,
    this.loadItems,
    required this.onChanged,
    required this.hint,
  });

  final String? value;
  final List<String> items;
  final Future<List<String>> Function()? loadItems;
  final ValueChanged<String?> onChanged;
  final String hint;

  @override
  State<_SearchableDropdownField> createState() =>
      _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState extends State<_SearchableDropdownField> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  List<String> _resolvedItems = <String>[];
  bool _isLoadingItems = false;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.value ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _resolvedItems = List<String>.from(widget.items);
  }

  @override
  void didUpdateWidget(_SearchableDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _searchController.text = widget.value ?? '';
    }
    if (widget.items != oldWidget.items && widget.loadItems == null) {
      _resolvedItems = List<String>.from(widget.items);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _loadItemsIfNeeded();
    }

    setState(() {
      _isOpen = _focusNode.hasFocus;
    });
  }

  Future<void> _loadItemsIfNeeded() async {
    if (widget.loadItems == null || _isLoadingItems) {
      return;
    }

    setState(() {
      _isLoadingItems = true;
    });

    try {
      final List<String> loadedItems = await widget.loadItems!();
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvedItems = loadedItems;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
        });
      }
    }
  }

  List<String> _getFilteredItems() {
    final String query = _searchController.text.toLowerCase();
    final List<String> sourceItems =
        _resolvedItems.isNotEmpty ? _resolvedItems : widget.items;
    if (query.isEmpty) {
      return sourceItems;
    }
    return sourceItems
        .where((String item) => item.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> filteredItems = _getFilteredItems();

    return TextFieldTapRegion(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE9ECF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    _isOpen ? const Color(0xFF2D5F8C) : const Color(0xFFD1D8E6),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: const TextStyle(
                        color: Color(0xFF8B94A8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1E232D),
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (String value) {
                      if (value.isEmpty && widget.value != null) {
                        widget.onChanged(null);
                      }
                      setState(() {});
                    },
                    onSubmitted: (String value) {
                      if (value.trim().isEmpty) {
                        widget.onChanged(null);
                      }
                      _focusNode.unfocus();
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    _focusNode.unfocus();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF5D667A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isOpen)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD1D8E6),
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: _isLoadingItems
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : filteredItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF667089),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String item = filteredItems[index];
                            final bool isSelected = widget.value == item;

                            return InkWell(
                              onTap: () {
                                _searchController.text = item;
                                widget.onChanged(item);
                                _focusNode.unfocus();
                                setState(() {
                                  _isOpen = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE8EEF8)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected
                                              ? const Color(0xFF2D5F8C)
                                              : const Color(0xFF1E232D),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Color(0xFF2D5F8C),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
        ],
      ),
    );
  }
}

class _QueueTask {
  const _QueueTask({
    required this.urgency,
    required this.timestamp,
    required this.title,
    required this.dealer,
    required this.urgencyColor,
    required this.urgencyTextColor,
    required this.user,
    required this.category,
    required this.department,
    required this.status,
  });

  final String urgency;
  final String timestamp;
  final String title;
  final String dealer;
  final Color urgencyColor;
  final Color urgencyTextColor;
  final String user;
  final String category;
  final String department;
  final String status;
}
