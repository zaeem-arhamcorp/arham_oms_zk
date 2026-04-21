import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/tasks/models/self_assign_task_model.dart';
import 'package:arham_corporation/views/tasks/models/task_detail_model.dart';
import 'package:arham_corporation/views/tasks/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TaskDetailView extends StatefulWidget {
  const TaskDetailView({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  bool _isLoading = true;
  String? _errorMessage;
  TaskDetailResponse? _detailResponse;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final UserProvider userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final String? token = userProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final TaskDetailResponse response = await TaskApiService.getIssueDetails(
        token: token,
        issueId: widget.task.issueId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detailResponse = response;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Error loading issue details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final IssueDetailData? issue = _detailResponse?.data;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: const Text('Task Details'),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
              : issue == null
                  ? const Center(child: Text('No issue details found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SectionCard(
                            title: issue.issueTitle,
                            children: <Widget>[
                              _DetailRow(
                                  label: 'Issue ID', value: issue.issueId),
                              _DetailRow(
                                  label: 'Dealer', value: issue.dealerCd),
                              _DetailRow(
                                  label: 'Department',
                                  value: issue.assignedDeptCd),
                              _DetailRow(
                                  label: 'Category', value: issue.category),
                              _DetailRow(
                                  label: 'Priority', value: issue.priority),
                              _DetailRow(label: 'Status', value: issue.status),
                              _DetailRow(label: 'Source', value: issue.source),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Description',
                            children: <Widget>[
                              Text(
                                issue.issueDescription,
                                style:
                                    const TextStyle(fontSize: 15, height: 1.4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Assigned Task',
                            children: <Widget>[
                              for (final Task task in issue.tasks)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _DetailRow(
                                          label: 'Task ID', value: task.taskId),
                                      _DetailRow(
                                          label: 'Task Name',
                                          value: task.taskName ?? '-'),
                                      _DetailRow(
                                          label: 'Dept',
                                          value: task.deptName ?? task.deptCd),
                                      _DetailRow(
                                          label: 'Stockist',
                                          value: task.stockistName ??
                                              task.dealerCd),
                                      _DetailRow(
                                          label: 'Assignee',
                                          value: task.assigneeUserName ??
                                              task.assigneeUserCd),
                                      const Divider(height: 20),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Timeline',
                            children: <Widget>[
                              for (final IssueTimelineEntry entry
                                  in issue.timeline)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(entry.action,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(entry.note),
                                      const SizedBox(height: 4),
                                      Text(entry.at,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF161C27),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5B6475),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E232D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
