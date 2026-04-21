import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/tasks/models/assign_issue_model.dart';
import 'package:arham_corporation/views/tasks/models/department_model.dart';
import 'package:arham_corporation/views/tasks/models/stockist_model.dart';
import 'package:arham_corporation/views/tasks/services/api_service.dart';
import 'package:arham_corporation/views/tasks/task_list_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class AssignTaskView extends StatefulWidget {
  const AssignTaskView({super.key});

  @override
  State<AssignTaskView> createState() => _AssignTaskViewState();
}

class _AssignTaskViewState extends State<AssignTaskView> {
  final TextEditingController _partnerController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Data lists
  List<Stockist> _stockists = [];
  List<String> _departmentCodes = [];

  // Selected values
  Stockist? _selectedStockist;
  String? _selectedDepartmentCode;
  String? _selectedCategory;
  DateTime? _selectedDueDate;
  String _selectedUrgency = 'High';

  // Loading states
  bool _isLoadingStockists = true;
  bool _isLoadingDepartments = true;
  bool _isSubmitting = false;

  static const List<String> _categoryOptions = <String>[
    'Billing Conflict',
    'Service Escalation',
    'Contract Clarification',
    'Stock Availability',
    'Other',
  ];

  void _logDebug(String message) {
    debugPrint('[AssignTaskView] $message');
  }

  String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDueDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _selectedDueDate ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDueDate = picked;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchStockists();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _partnerController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchStockists() async {
    try {
      _logDebug('_fetchStockists started');
      final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
      final String? token = ub.token;

      _logDebug('Current token from UserProvider: ${ub.token}');
      _logDebug('Token passed to stockists API: $token');
      _logDebug('Stockists API URL: ${AppConfig.getStockistsURL}');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final StockistResponse response =
          await TaskApiService.getStockists(token: token);

      _logDebug(
          'Stockists parsed response: status=${response.status}, message=${response.message}, count=${response.data.length}');

      setState(() {
        _stockists = response.data;
        _isLoadingStockists = false;
      });
    } catch (e) {
      _logDebug('_fetchStockists error: $e');
      print('Error fetching stockists: $e');
      setState(() {
        _isLoadingStockists = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stockists: $e')),
        );
      }
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      _logDebug('_fetchDepartments started');
      final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
      final String? token = ub.token;

      _logDebug('Current token from UserProvider: ${ub.token}');
      _logDebug('Token passed to departments API: $token');
      _logDebug('Departments API URL: ${AppConfig.getMyDepartmentsURL}');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final DepartmentResponse response =
          await TaskApiService.getMyDepartments(token: token);

      _logDebug(
          'Departments parsed response: status=${response.status}, message=${response.message}, codes=${response.data.deptCodes.length}');

      setState(() {
        _departmentCodes = response.data.deptCodes;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      _logDebug('_fetchDepartments error: $e');
      print('Error fetching departments: $e');
      setState(() {
        _isLoadingDepartments = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading departments: $e')),
        );
      }
    }
  }

  Future<void> _submitAssignIssue() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (_selectedStockist == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a dealer')),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter issue title')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter issue description')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category')),
      );
      return;
    }

    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select due date')),
      );
      return;
    }

    if (_selectedDepartmentCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select department')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      _logDebug('_submitAssignIssue started');
      final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
      final String? token = ub.token;

      _logDebug('Current token from UserProvider: ${ub.token}');
      _logDebug('Token passed to assign-issue API: $token');
      _logDebug('Assign issue API URL: ${AppConfig.assignIssueURL}');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final AssignIssueRequest request = AssignIssueRequest(
        dealerCd: _selectedStockist!.accCd,
        issueTitle: title,
        issueDescription: description,
        category: _selectedCategory!,
        dueDate: _formatDate(_selectedDueDate!),
        priority: _selectedUrgency,
        assignDeptCd: _selectedDepartmentCode!,
        // visitId is nullable, don't set it
      );

      _logDebug('Assign issue request body: ${request.toJson()}');

      final AssignIssueResponse response = await TaskApiService.assignIssue(
        token: token,
        request: request,
      );

      _logDebug(
          'Assign issue parsed response: status=${response.status}, message=${response.message}, data=${response.data}');

      // Response was successfully parsed from HTTP 200/201, so show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear form
      _partnerController.clear();
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedStockist = null;
        _selectedCategory = null;
        _selectedDueDate = null;
        _selectedDepartmentCode = null;
        _selectedUrgency = 'High';
      });
    } catch (e) {
      _logDebug('_submitAssignIssue error: $e');
      print('Error submitting issue: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _openDealershipBottomSheet() async {
    final Stockist? picked = await showModalBottomSheet<Stockist>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        String query = '';

        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setModalState) {
            final List<Stockist> filteredStockists =
                _stockists.where((Stockist stockist) {
              return stockist.accName
                      .toLowerCase()
                      .contains(query.toLowerCase()) ||
                  stockist.personNm.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D8E6),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Text(
                            'Select Dealership',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF171A21),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF5B6475),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9ECF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (String value) {
                            setModalState(() {
                              query = value.trim();
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 22,
                              color: Color(0xFF79849B),
                            ),
                            hintText: 'Search dealerships',
                            hintStyle: TextStyle(
                              color: Color(0xFF8F98AC),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E232D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filteredStockists.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching dealership found',
                                  style: TextStyle(
                                    color: Color(0xFF667089),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredStockists.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final Stockist stockist =
                                      filteredStockists[index];
                                  final bool isSelected =
                                      _selectedStockist?.accCd ==
                                          stockist.accCd;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(modalContext).pop(stockist);
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFDDE8F8)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2D5F8C)
                                              : const Color(0xFFDEE3ED),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE7EDF8),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.store_outlined,
                                              color: Color(0xFF2D5F8C),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Text(
                                                  stockist.accName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF1B1F29),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  stockist.city,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF8B94A8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
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
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedStockist = picked;
      _partnerController.text = picked.accName;
    });
  }

  Future<void> _openCategoryBottomSheet() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        String query = '';

        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setModalState) {
            final List<String> filteredCategories =
                _categoryOptions.where((String category) {
              return category.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D8E6),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Text(
                            'Select Category',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF171A21),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF5B6475),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9ECF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (String value) {
                            setModalState(() {
                              query = value.trim();
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 22,
                              color: Color(0xFF79849B),
                            ),
                            hintText: 'Search categories',
                            hintStyle: TextStyle(
                              color: Color(0xFF8F98AC),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E232D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filteredCategories.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching category found',
                                  style: TextStyle(
                                    color: Color(0xFF667089),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredCategories.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final String category =
                                      filteredCategories[index];
                                  final bool isSelected =
                                      _selectedCategory == category;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(modalContext).pop(category);
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFDDE8F8)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2D5F8C)
                                              : const Color(0xFFDEE3ED),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE7EDF8),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.category_outlined,
                                              color: Color(0xFF2D5F8C),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Color(0xFF1B1F29),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
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
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedCategory = picked;
    });
  }

  Future<void> _openDepartmentBottomSheet() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        String query = '';

        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setModalState) {
            final List<String> filteredDepartments =
                _departmentCodes.where((String dept) {
              return dept.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D8E6),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Text(
                            'Select Department',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF171A21),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF5B6475),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9ECF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (String value) {
                            setModalState(() {
                              query = value.trim();
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                            prefixIcon: Icon(
                              Icons.search,
                              size: 22,
                              color: Color(0xFF79849B),
                            ),
                            hintText: 'Search departments',
                            hintStyle: TextStyle(
                              color: Color(0xFF8F98AC),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E232D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filteredDepartments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching department found',
                                  style: TextStyle(
                                    color: Color(0xFF667089),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredDepartments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (BuildContext context, int index) {
                                  final String dept =
                                      filteredDepartments[index];
                                  final bool isSelected =
                                      _selectedDepartmentCode == dept;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(modalContext).pop(dept);
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFDDE8F8)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2D5F8C)
                                              : const Color(0xFFDEE3ED),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE7EDF8),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.apartment_outlined,
                                              color: Color(0xFF2D5F8C),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              dept,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: Color(0xFF1B1F29),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
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
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedDepartmentCode = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F8),
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Assign Task',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Get.to(() => TaskListView());
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // _buildTopHeader(),
              // const SizedBox(height: 12),
              // const Text(
              //   'SALES PORTAL   >   ISSUE INTAKE',
              //   style: TextStyle(
              //     fontSize: 11,
              //     color: Color(0xFF747E91),
              //     fontWeight: FontWeight.w600,
              //     letterSpacing: 1.2,
              //   ),
              // ),
              // const SizedBox(height: 16),
              _buildFormCard(),
              // const SizedBox(height: 16),
              // _buildRoutingCard(),
              const SizedBox(height: 16),
              _buildStatsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(Icons.arrow_back),
        ),
        // Container(
        //   width: 34,
        //   height: 34,
        //   decoration: BoxDecoration(
        //     color: const Color(0xFFE1E8F2),
        //     borderRadius: BorderRadius.circular(17),
        //   ),
        //   child: const Icon(
        //     Icons.person_outline,
        //     size: 18,
        //     color: Color(0xFF2D5F8C),
        //   ),
        // ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Assign Task',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: 1.2,
              color: Color(0xFF1E232D),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Get.to(() => TaskListView());
          },
          icon: const Icon(Icons.notifications_none_rounded),
          color: const Color(0xFF4E5D76),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Raise New Issue',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF171A22),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Initiate a formal resolution workflow for partner dealerships.',
            style: TextStyle(
              color: Color(0xFF616A7D),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _buildFieldLabel('DEALER NAME'),
          InkWell(
            onTap: _openDealershipBottomSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.store_outlined,
                    color: Color(0xFF8892A8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedStockist?.accName ??
                          'Search and select dealership',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _selectedStockist != null
                            ? const Color(0xFF1E232D)
                            : const Color(0xFF8B94A8),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF5D667A),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('ISSUE TITLE'),
          _buildInputContainer(
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Brief summary of the conflict',
                hintStyle: TextStyle(
                  color: Color(0xFF8B94A8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('DETAILED DESCRIPTION'),
          _buildInputContainer(
            child: SizedBox(
              height: 136,
              child: TextField(
                controller: _descriptionController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      'Provide technical details and historical context...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8B94A8),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('CLASSIFICATION CATEGORY'),
          InkWell(
            onTap: _openCategoryBottomSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.category_outlined,
                    color: Color(0xFF8892A8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedCategory ?? 'Select category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _selectedCategory != null
                            ? const Color(0xFF1E232D)
                            : const Color(0xFF8B94A8),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF5D667A),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('DUE DATE'),
          InkWell(
            onTap: _pickDueDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.event_outlined,
                    color: Color(0xFF8892A8),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedDueDate != null
                          ? _formatDate(_selectedDueDate!)
                          : 'Select due date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _selectedDueDate != null
                            ? const Color(0xFF1E232D)
                            : const Color(0xFF8B94A8),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF5D667A),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('URGENCY MATRIX'),
          Row(
            children: <Widget>[
              _buildUrgencyButton('High'),
              const SizedBox(width: 8),
              _buildUrgencyButton('Medium'),
              const SizedBox(width: 8),
              _buildUrgencyButton('Low'),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('ASSIGN TO DEPARTMENT'),
          InkWell(
            onTap: _openDepartmentBottomSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.apartment_outlined,
                    color: Color(0xFF2D5F8C),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDepartmentCode ?? 'Tap to choose department',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedDepartmentCode != null
                            ? const Color(0xFF1E232D)
                            : const Color(0xFF8B94A8),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF5D667A),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAssignIssue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245B87),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Assign Task',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildRoutingCard() {
  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
  //     decoration: BoxDecoration(
  //       color: const Color(0xFF2C5D88),
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: const <Widget>[
  //         Icon(Icons.auto_awesome, color: Color(0xFFCBE0FA), size: 20),
  //         SizedBox(height: 8),
  //         Text(
  //           'Automated Routing',
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 17,
  //             fontWeight: FontWeight.w700,
  //           ),
  //         ),
  //         SizedBox(height: 6),
  //         Text(
  //           'Routing depends on the selected dealership\'s priority status and current quarterly volume.',
  //           style: TextStyle(
  //             color: Color(0xFFD8E8F8),
  //             fontSize: 14,
  //             height: 1.32,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'LIVE ASSIGNMENT STATS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF657086),
            ),
          ),
          const SizedBox(height: 12),
          _buildStatsRow(
            dotColor: const Color(0xFFB12222),
            label: 'Critical Tasks',
            value: '04',
          ),
          const SizedBox(height: 10),
          _buildStatsRow(
            dotColor: const Color(0xFFEDB600),
            label: 'Tasks In Progress',
            value: '12',
          ),
          const SizedBox(height: 10),
          _buildStatsRow(
            dotColor: const Color(0xFF5D538F),
            label: 'Pending Tasks',
            value: '12',
          ),
          const SizedBox(height: 10),
          _buildStatsRow(
            dotColor: const Color(0xFF00A110),
            label: 'Completed',
            value: '12',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required Color dotColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1F2531),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF121722),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Widget _buildBottomNav() {
  //   return Container(
  //     height: 82,
  //     decoration: const BoxDecoration(
  //       color: Color(0xFFF4F6FB),
  //       border: Border(top: BorderSide(color: Color(0xFFD9DEEA))),
  //     ),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //       children: <Widget>[
  //         _buildBottomTabItem(
  //           index: 0,
  //           icon: Icons.warning_amber_rounded,
  //           label: 'ISSUES',
  //         ),
  //         _buildBottomTabItem(
  //           index: 1,
  //           icon: Icons.task_alt_rounded,
  //           label: 'TASKS',
  //         ),
  //         _buildBottomTabItem(
  //           index: 2,
  //           icon: Icons.person_outline,
  //           label: 'PROFILE',
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF636E83),
        ),
      ),
    );
  }

  Widget _buildInputContainer({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _buildUrgencyButton(String level) {
    final bool isSelected = _selectedUrgency == level;
    Color borderColor = const Color(0xFFC5CBD9);
    Color textColor = const Color(0xFF2C364A);
    Color backgroundColor = const Color(0xFFF1F3F8);

    if (level == 'High' && isSelected) {
      borderColor = const Color(0xFFD89A9A);
      textColor = const Color(0xFFC82A2A);
      backgroundColor = const Color(0xFFFDEEEF);
    } else if (level == 'Medium' && isSelected) {
      borderColor = const Color(0xFF9C9AD8); //0xFFD8C49A
      textColor = const Color(0xFF4D4A88); //0xFFC8792A
      backgroundColor = const Color(0xFFD9D8F3);
    } else if (isSelected) {
      borderColor = const Color(0xFF879BBA);
      textColor = const Color(0xFF2D5F8C);
      backgroundColor = const Color(0xFFE8EEF8);
    }

    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedUrgency = level;
          });
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          backgroundColor: backgroundColor,
          fixedSize: const Size.fromHeight(46),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          level,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DepartmentOption {
  const _DepartmentOption({required this.name, required this.icon});

  final String name;
  final IconData icon;
}
