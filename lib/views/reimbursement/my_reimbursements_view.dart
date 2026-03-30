import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MyReimbursementsView extends StatefulWidget {
  const MyReimbursementsView({super.key});

  @override
  State<MyReimbursementsView> createState() => _MyReimbursementsViewState();
}

class _MyReimbursementsViewState extends State<MyReimbursementsView> {
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  late DateTime _fromDate;
  late DateTime _toDate;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][MyRequests] Screen initialized');
    final DateTime now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
    debugPrint(
      '[Reimbursement][MyRequests] Default date range: ${_apiDateFormat.format(_fromDate)} to ${_apiDateFormat.format(_toDate)}',
    );
    _fetchReimbursements();
  }

  Future<void> _fetchReimbursements() async {
    debugPrint('[Reimbursement][MyRequests][API] Fetch started');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? token =
          Provider.of<UserProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        debugPrint('[Reimbursement][MyRequests][API] Missing token');
        setState(() {
          _errorMessage = 'User token not found. Please login again.';
          _isLoading = false;
        });
        return;
      }
      debugPrint('[Reimbursement][MyRequests][API] Token: $token');

      final uri = Uri.parse('${AppConfig.baseURL}users/reimbursements').replace(
        queryParameters: {
          'fromDate': _apiDateFormat.format(_fromDate),
          'toDate': _apiDateFormat.format(_toDate),
        },
      );
      debugPrint('[Reimbursement][MyRequests][API] GET $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
        '[Reimbursement][MyRequests][API] Response status: ${response.statusCode}',
      );
      debugPrint(
          '[Reimbursement][MyRequests][API] Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = decoded['data'];
        final List<Map<String, dynamic>> parsed = (data is List)
            ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _requests = parsed;
          _isLoading = false;
        });
        debugPrint(
            '[Reimbursement][MyRequests][API] Parsed ${parsed.length} records');
      } else {
        setState(() {
          _errorMessage =
              (decoded['message'] ?? 'Failed to fetch reimbursements')
                  .toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Reimbursement][MyRequests][API] Exception: $e');
      setState(() {
        _errorMessage = 'Failed to fetch reimbursements: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    debugPrint(
      '[Reimbursement][MyRequests] Opening ${isFromDate ? 'fromDate' : 'toDate'} picker',
    );
    final DateTime initialDate = isFromDate ? _fromDate : _toDate;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      if (isFromDate) {
        _fromDate = pickedDate;
        if (_fromDate.isAfter(_toDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = pickedDate;
        if (_toDate.isBefore(_fromDate)) {
          _fromDate = _toDate;
        }
      }
    });
    debugPrint(
      '[Reimbursement][MyRequests] Selected range: ${_apiDateFormat.format(_fromDate)} to ${_apiDateFormat.format(_toDate)}',
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

  String _formatDate(dynamic value) {
    final String text = (value ?? '').toString();
    if (text.isEmpty) return '-';

    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter By Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFromDate: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                        ),
                        Text(' From: ${_apiDateFormat.format(_fromDate)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFromDate: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                        ),
                        Text(' To: ${_apiDateFormat.format(_toDate)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _fetchReimbursements,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String status = (request['STATUS'] ?? 'PENDING').toString();
    final String expenseType = (request['EXPENSE_TYPE'] ?? '-').toString();
    final String amount = (request['AMOUNT'] ?? '-').toString();
    final String notes = (request['NOTES'] ?? '-').toString();
    final String actionNote = (request['ACTION_NOTE'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expenseType,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(height: 8),
            Text('Amount: ₹$amount'),
            Text('Date: ${_formatDate(request['EXPENSE_DT'])}'),
            const SizedBox(height: 4),
            Text('Notes: $notes'),
            if (actionNote.isNotEmpty && actionNote != 'null') ...[
              const SizedBox(height: 4),
              Text('Action Note: $actionNote'),
            ],
            const SizedBox(height: 4),
            Text('Approver: ${(request['APPROVER_NAME'] ?? '-').toString()}'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchReimbursements,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(child: Text('No reimbursement requests found.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchReimbursements,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Reimbursement][MyRequests] Building screen');
    return Scaffold(
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
