import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/monthly_target_item_model.dart';
import '../models/monthly_target_request_model.dart';
import '../services/api_services.dart';

class MonthlyTargetView extends StatefulWidget {
  const MonthlyTargetView({super.key});

  @override
  State<MonthlyTargetView> createState() => _MonthlyTargetViewState();
}

class _MonthlyTargetViewState extends State<MonthlyTargetView> {
  late final MonthlyTargetApiService _service;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _targetMonthController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _filterTargetMonthController =
      TextEditingController(text: '');
  final TextEditingController _filterStockistCdController =
      TextEditingController(text: '');
  final TextEditingController _filterUserCdController =
      TextEditingController(text: '');
  final TextEditingController _filterModuleNoController =
      TextEditingController(text: '');
  final TextEditingController _filterTypeController =
      TextEditingController(text: 'POB');
  final TextEditingController _filterTargetDescController =
      TextEditingController(text: '');

  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isSubmitting = false;
  bool _isLoadingList = false;
  List<MonthlyTargetItemModel> _allTargets = [];
  List<MonthlyTargetItemModel> _visibleTargets = [];
  MonthlyTargetItemModel? _currentMonthTarget;

  @override
  void initState() {
    super.initState();
    _service = Get.isRegistered<MonthlyTargetApiService>()
        ? Get.find<MonthlyTargetApiService>()
        : Get.put(MonthlyTargetApiService());
    _targetMonthController.text =
        DateFormat('MMMM yyyy').format(_selectedMonth);
    _loadMonthlyTargets();
  }

  @override
  void dispose() {
    _targetMonthController.dispose();
    _amountController.dispose();

    _filterTargetMonthController.dispose();
    _filterStockistCdController.dispose();
    _filterUserCdController.dispose();
    _filterModuleNoController.dispose();
    _filterTypeController.dispose();
    _filterTargetDescController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthlyTargets() async {
    final userProvider = context.read<UserProvider>();
    setState(() {
      _isLoadingList = true;
    });

    final targets = await _service.fetchMonthlyTargets(
      targetMonth: _selectedMonth.toIso8601String().split('T').first,
      userCd:
          (Provider.of<ProfileProvider>(context, listen: false).data?.userCd ??
                  '')
              .toString()
              .trim(),
      token: userProvider.token,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _allTargets = targets;
      _applyFilters();
      _isLoadingList = false;
    });

    _syncCurrentMonthTarget(targets);
  }

  void _syncCurrentMonthTarget(List<MonthlyTargetItemModel> targets) {
    final currentMonthKey = _selectedMonth.toIso8601String().split('T').first;
    final currentUserCd =
        (Provider.of<ProfileProvider>(context, listen: false).data?.userCd ??
                '')
            .toString()
            .trim();

    final matches = targets.where((target) {
      final monthMatches =
          target.targetDate.startsWith(currentMonthKey.substring(0, 7));
      final userMatches =
          currentUserCd.isEmpty || target.userCd.trim() == currentUserCd;
      return monthMatches && userMatches && target.type.toUpperCase() == 'POB';
    }).toList();

    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final selected = matches.isNotEmpty ? matches.first : null;

    setState(() {
      _currentMonthTarget = selected;

      // Preload editable target field with current month amount when available.
      if (selected != null && _amountController.text.trim().isEmpty) {
        _amountController.text =
            selected.salesmanTargetAmount.toStringAsFixed(0);
      }
    });
  }

  void _applyFilters() {
    String f(String v) => v.trim().toLowerCase();

    final targetMonth = f(_filterTargetMonthController.text);
    final stockistCd = f(_filterStockistCdController.text);
    final userCd = f(_filterUserCdController.text);
    final moduleNo = f(_filterModuleNoController.text);
    final type = f(_filterTypeController.text);
    final targetDesc = f(_filterTargetDescController.text);

    _visibleTargets = _allTargets.where((item) {
      final targetMonthOk = targetMonth.isEmpty ||
          item.targetMonth.toLowerCase().contains(targetMonth);
      final stockistOk = stockistCd.isEmpty ||
          item.stockistCd.toLowerCase().contains(stockistCd);
      final userOk =
          userCd.isEmpty || item.userCd.toLowerCase().contains(userCd);
      final moduleOk =
          moduleNo.isEmpty || item.moduleNo.toLowerCase().contains(moduleNo);
      final typeOk = type.isEmpty || item.type.toLowerCase().contains(type);
      final targetDescOk = targetDesc.isEmpty ||
          item.targetDesc.toLowerCase().contains(targetDesc);
      return targetMonthOk &&
          stockistOk &&
          userOk &&
          moduleOk &&
          typeOk &&
          targetDescOk;
    }).toList();
  }

  Future<void> _openFilterDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Filter Monthly Targets'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _filterTargetMonthController,
                  decoration: const InputDecoration(labelText: 'targetMonth'),
                ),
                TextField(
                  controller: _filterStockistCdController,
                  decoration: const InputDecoration(labelText: 'stockistCd'),
                ),
                TextField(
                  controller: _filterUserCdController,
                  decoration: const InputDecoration(labelText: 'userCd'),
                ),
                TextField(
                  controller: _filterModuleNoController,
                  decoration: const InputDecoration(labelText: 'moduleNo'),
                ),
                TextField(
                  controller: _filterTypeController,
                  decoration: const InputDecoration(labelText: 'type'),
                ),
                TextField(
                  controller: _filterTargetDescController,
                  decoration: const InputDecoration(labelText: 'targetDesc'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _filterTargetMonthController.clear();
                _filterStockistCdController.clear();
                _filterUserCdController.clear();
                _filterModuleNoController.clear();
                _filterTypeController.clear();
                _filterTargetDescController.clear();
                setState(_applyFilters);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                setState(_applyFilters);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select target month',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
      _targetMonthController.text =
          DateFormat('MMMM yyyy').format(_selectedMonth);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Enter a valid target amount',
        backgroundColor: Colors.red,
      );
      return;
    }

    final userProvider = context.read<UserProvider>();

    setState(() {
      _isSubmitting = true;
    });

    final result = await _service.saveMonthlyTarget(
      MonthlyTargetRequestModel(
        targetDate: _selectedMonth,
        salesmanTargetAmount: amount,
      ),
      token: userProvider.token,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    AppSnackBar.showGetXCustomSnackBar(
      message: result.message,
      backgroundColor: result.message.toLowerCase().contains('success')
          ? Colors.green
          : Colors.red,
    );

    if (result.data != null) {
      _amountController.text = amount.toString();
      final created = MonthlyTargetItemModel.fromJson(result.data!);
      setState(() {
        _allTargets.insert(0, created);
        _currentMonthTarget = created;
        _applyFilters();
      });
    }
  }

  Widget _buildTargetCard(MonthlyTargetItemModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${item.id} | TYPE: ${item.type}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Target Month: ${item.targetMonth}'),
            Text('Target Date: ${item.targetDate}'),
            Text(
                'Stockist: ${item.stockistCd.isEmpty ? '-' : item.stockistCd}'),
            Text('User: ${item.userCd.isEmpty ? '-' : item.userCd}'),
            Text('Module: ${item.moduleNo.isEmpty ? '-' : item.moduleNo}'),
            Text(
                'Target Desc: ${item.targetDesc.isEmpty ? '-' : item.targetDesc}'),
            Text('Salesman Target Amount: ${item.salesmanTargetAmount}'),
            Text('POB Amount: ${item.pobAmount}'),
            Text(
                'POB Last Sync: ${item.pobLastSyncAt.isEmpty || item.pobLastSyncAt == 'null' ? '-' : item.pobLastSyncAt}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Monthly Target",
        actions: [
          IconButton(
            onPressed: _openFilterDialog,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _targetMonthController,
                readOnly: true,
                onTap: _pickMonth,
                decoration: const InputDecoration(
                  labelText: 'Target Month',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Select target month'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Salesman Target Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter target amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Monthly Target'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Monthly Target List',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadMonthlyTargets,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              if (_isLoadingList)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_visibleTargets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No monthly target data found.'),
                )
              else
                ListView.builder(
                  itemCount: _visibleTargets.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _buildTargetCard(_visibleTargets[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
