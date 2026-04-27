import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/reimbursement/reimbursement_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MyReimbursementsView extends StatefulWidget {
  const MyReimbursementsView({super.key});

  @override
  State<MyReimbursementsView> createState() => _MyReimbursementsViewState();
}

class _MyReimbursementsViewState extends State<MyReimbursementsView>
    with AutomaticKeepAliveClientMixin {
  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  late DateTime _fromDate;
  late DateTime _toDate;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  int _myRequestCount = 0;
  double _myAmountTotal = 0.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][MyRequests] Screen initialized');
    final DateTime now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    debugPrint(
      '[Reimbursement][MyRequests] Default date range: ${_apiDateFormat.format(_fromDate)} to ${_apiDateFormat.format(_toDate)}',
    );
    _fetchReimbursements();
  }

  Future<void> _fetchReimbursements() async {
    debugPrint('[Reimbursement][MyRequests][API] Fetch started');
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool online = await NetworkHelper.hasInternet();
      if (!online) {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
        if (!mounted) return;
        setState(() {
          _requests = <Map<String, dynamic>>[];
          _myRequestCount = 0;
          _myAmountTotal = 0.0;
          _errorMessage = null;
          _isLoading = false;
        });
        return;
      }

      final String? token =
          Provider.of<UserProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        debugPrint('[Reimbursement][MyRequests][API] Missing token');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'User token not found. Please login again.';
          _isLoading = false;
        });
        return;
      }
      debugPrint('[Reimbursement][MyRequests][API] Token: $token');

      final String? syncId =
          Provider.of<UserProvider>(context, listen: false).syncId;
      if (syncId == null || syncId.isEmpty) {
        debugPrint('[Reimbursement][MyRequests][API] Missing syncId');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Firm information not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final uri = Uri.parse('${AppConfig.baseURL}users/reimbursements').replace(
        queryParameters: {
          'fromDate': _apiDateFormat.format(_fromDate),
          'toDate': _apiDateFormat.format(_toDate),
          'sync_Id': syncId,
        },
      );
      debugPrint('[Reimbursement][MyRequests][API] GET $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      );

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
        '[Reimbursement][MyRequests][API] Response status: ${response.statusCode}',
      );
      debugPrint(
          '[Reimbursement][MyRequests][API] Response length: ${response.body.length} bytes');

      if (!mounted) return;

      final dynamic rawData = decoded['data'];
      final List<Map<String, dynamic>> allRecords = (rawData is List)
          ? rawData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      debugPrint(
          '[Reimbursement][MyRequests][API] Total records from API: ${allRecords.length}');

      if (allRecords.isNotEmpty) {
        final syncIds = allRecords.map((e) => e['SYNC_ID']).join(', ');
        debugPrint(
            '[Reimbursement][MyRequests][API] SYNC_IDs in response: $syncIds');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<Map<String, dynamic>> parsed = allRecords.where((e) {
          // Client-side filtering: only include records for current firm
          final recordSyncId = (e['SYNC_ID']?.toString() ?? '');
          final matches = recordSyncId == syncId;
          if (!matches) {
            debugPrint(
                '[Reimbursement][MyRequests][API] Filtering out EXPENSE_ID=${e['EXPENSE_ID']}, SYNC_ID=$recordSyncId (expected $syncId)');
          }
          return matches;
        }).toList();

        // Parse stats
        final dynamic stats = decoded['stats'];
        int requestCount = 0;
        double amountTotal = 0.0;

        if (stats is Map<String, dynamic>) {
          requestCount = (stats['myRequestCount'] ?? 0) as int;
          final amountValue = stats['myAmountTotal'] ?? 0;
          amountTotal = (amountValue is int)
              ? amountValue.toDouble()
              : (amountValue as double?)?.toDouble() ?? 0.0;
        }

        setState(() {
          _requests = parsed;
          _myRequestCount = requestCount;
          _myAmountTotal = amountTotal;
          _isLoading = false;
        });
        debugPrint(
            '[Reimbursement][MyRequests][API] After filtering: ${parsed.length} of ${allRecords.length} records');
        debugPrint(
            '[Reimbursement][MyRequests][API] Stats: count=$requestCount, total=$amountTotal');
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
      if (!mounted) return;

      final bool isOfflineSocketIssue =
          e is SocketException || e.toString().contains('SocketException');
      if (isOfflineSocketIssue) {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
        setState(() {
          _requests = <Map<String, dynamic>>[];
          _myRequestCount = 0;
          _myAmountTotal = 0.0;
          _errorMessage = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = 'Failed to fetch reimbursements';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    debugPrint(
      '[Reimbursement][MyRequests] Opening ${isFromDate ? 'fromDate' : 'toDate'} picker',
    );
    DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2000, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      currentTime: isFromDate ? _fromDate : _toDate,
      locale: LocaleType.en,
      onConfirm: (date) async {
        if (!mounted) return;
        final DateTime pickedDate = DateTime(date.year, date.month, date.day);

        final DateTime oldFromDate = _fromDate;
        final DateTime oldToDate = _toDate;

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

        if (oldFromDate != _fromDate || oldToDate != _toDate) {
          await _fetchReimbursements();
        }
      },
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

  bool _isWithin24Hours(dynamic createdAt) {
    if (createdAt == null) return false;
    final String text = createdAt.toString();
    if (text.isEmpty) return false;

    final DateTime? createdDate = DateTime.tryParse(text);
    if (createdDate == null) return false;

    final DateTime now = DateTime.now();
    final Duration difference = now.difference(createdDate);
    return difference.inHours < 24;
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'From',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'To',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFromDate: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_apiDateFormat.format(_fromDate)),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_apiDateFormat.format(_toDate)}'),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    final bool isEditable = status.toUpperCase() == 'PENDING' &&
        _isWithin24Hours(request['CREATED_AT']);

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
                if (isEditable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReimbursementEditPage(
                            request: request,
                            onSave: _fetchReimbursements,
                          ),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Stats Card
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Requests',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _myRequestCount.toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_myAmountTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Requests List
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _requests.length,
            itemBuilder: (context, index) =>
                _buildRequestCard(_requests[index]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
