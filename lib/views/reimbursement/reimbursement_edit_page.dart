import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReimbursementEditPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onSave;

  const ReimbursementEditPage({
    super.key,
    required this.request,
    required this.onSave,
  });

  @override
  State<ReimbursementEditPage> createState() => _ReimbursementEditPageState();
}

class _ReimbursementEditPageState extends State<ReimbursementEditPage> {
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  static const List<String> expenseTypes = [
    'DAILY_ALLOWANCE',
    'OTHER_ALLOWANCE'
  ];

  late String _selectedExpenseType;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _dateController;
  late DateTime _selectedDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[Reimbursement][EditPage] Initializing with request: ${widget.request}');

    _selectedExpenseType =
        (widget.request['EXPENSE_TYPE'] ?? 'DAILY_ALLOWANCE').toString();
    _amountController = TextEditingController(
        text: (widget.request['AMOUNT'] ?? '').toString());
    _notesController =
        TextEditingController(text: (widget.request['NOTES'] ?? '').toString());

    // Initialize date
    final String? dateString = widget.request['DATE']?.toString();
    if (dateString != null && dateString.isNotEmpty) {
      _selectedDate = DateTime.tryParse(dateString) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }
    _dateController =
        TextEditingController(text: _displayDateFormat.format(_selectedDate));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic value) {
    final String text = (value ?? '').toString();
    if (text.isEmpty) return '-';

    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return _displayDateFormat.format(parsed);
  }

  Future<void> _updateReimbursement() async {
    if (_selectedExpenseType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expense type')),
      );
      return;
    }

    if (_dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date')),
      );
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String? token =
          Provider.of<UserProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('User token not found. Please login again.')),
          );
        }
        return;
      }

      final String expenseId =
          (widget.request['EXPENSE_ID'] ?? widget.request['ID'] ?? '')
              .toString();

      debugPrint('[Reimbursement][EditPage] Updating expense $expenseId');
      final uri =
          Uri.parse('${AppConfig.baseURL}users/reimbursements/$expenseId');

      final body = <String, dynamic>{
        'expenseType1': _selectedExpenseType,
        'date1': _apiDateFormat.format(_selectedDate),
        'amount1': _amountController.text.trim(),
        'notes1': _notesController.text.trim(),
      };

      debugPrint('[Reimbursement][EditPage] PUT $uri');
      debugPrint('[Reimbursement][EditPage] Body: $body');

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint(
          '[Reimbursement][EditPage] Response status: ${response.statusCode}');
      debugPrint('[Reimbursement][EditPage] Response body: ${response.body}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode >= 200 && response.statusCode < 300) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reimbursement updated successfully')),
          );
          widget.onSave();
          Navigator.pop(context);
        } else {
          final Map<String, dynamic> decoded =
              jsonDecode(response.body) as Map<String, dynamic>;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                decoded['message'] ?? 'Failed to update reimbursement',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Reimbursement][EditPage] Exception: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = (widget.request['STATUS'] ?? 'PENDING').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Reimbursement'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Field
            Text(
              'Date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Select date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Expense Type Dropdown
            Text(
              'Expense Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedExpenseType,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: expenseTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedExpenseType = newValue ?? 'DAILY_ALLOWANCE';
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Amount Field
            Text(
              'Amount',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Notes Field
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Enter notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateReimbursement,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _selectDate() async {
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime.now(),
      currentTime: _selectedDate,
      locale: LocaleType.en,
      onConfirm: (date) {
        if (!mounted) return;
        final picked = DateTime(date.year, date.month, date.day);
        if (picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
            _dateController.text = _displayDateFormat.format(_selectedDate);
          });
        }
      },
    );
  }
}
