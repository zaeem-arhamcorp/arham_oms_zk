import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../config/app_config.dart';
import '../../monthly_target/models/monthly_target_item_model.dart';
import '../../monthly_target/services/api_services.dart';

class EditMonthlyTargetView extends StatefulWidget {
  const EditMonthlyTargetView({super.key});

  @override
  State<EditMonthlyTargetView> createState() => _EditMonthlyTargetViewState();
}

class _EditMonthlyTargetViewState extends State<EditMonthlyTargetView> {
  late final MonthlyTargetApiService _service;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _targetMonthController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isSubmitting = false;
  bool _isLoadingList = false;
  List<MonthlyTargetItemModel> _allTargets = [];
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

    if (!mounted) return;

    setState(() {
      _allTargets = targets;
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
      if (selected != null && _amountController.text.trim().isEmpty) {
        _amountController.text =
            selected.salesmanTargetAmount.toStringAsFixed(0);
      }
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select target month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
      _targetMonthController.text =
          DateFormat('MMMM yyyy').format(_selectedMonth);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Enter a valid target amount', backgroundColor: Colors.red);
      return;
    }

    final userProvider = context.read<UserProvider>();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uri = Uri.parse('${AppConfig.baseURL}monthly-sales-target/bulk');
      final body = jsonEncode({
        'targetDate': _selectedMonth.toIso8601String().split('T').first,
        'type': 'POB',
        'salesmanTargetAmount': amount,
        'applyTo': 'all',
      });

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer ${userProvider.token}',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      print(uri);
      print(body);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Monthly target updated', backgroundColor: Colors.green);
        Navigator.of(context).pop(true);
      } else {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Failed to update monthly target',
            backgroundColor: Colors.red);
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Error: $e', backgroundColor: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Edit Monthly Target'),
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
                  if (value == null || value.trim().isEmpty)
                    return 'Enter target amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
