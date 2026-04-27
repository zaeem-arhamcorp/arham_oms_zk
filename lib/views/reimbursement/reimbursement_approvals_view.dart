import 'dart:convert';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../helper/network_helper.dart';
import '../../product/widget/app_snack_bar.dart';

// ApprovalActionSheet widget must be at the top of the file for visibility
class ApprovalActionSheet extends StatefulWidget {
  final int expenseId;
  final Future<bool> Function(String status, String note) onSubmit;
  const ApprovalActionSheet({
    super.key,
    required this.expenseId,
    required this.onSubmit,
  });

  @override
  State<ApprovalActionSheet> createState() => _ApprovalActionSheetState();
}

class _ApprovalActionSheetState extends State<ApprovalActionSheet> {
  late TextEditingController _noteController;
  String _selectedStatus = 'APPROVE';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Reimbursement #${widget.expenseId}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Action',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'APPROVE',
                  child: Text('APPROVE'),
                ),
                DropdownMenuItem(
                  value: 'REJECT',
                  child: Text('REJECT'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Enter approval/rejection note',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setState(() {
                          _isSubmitting = true;
                        });
                        final bool success = await widget.onSubmit(
                          _selectedStatus,
                          _noteController.text.trim(),
                        );
                        if (context.mounted && success) {
                          Navigator.pop(context);
                          return;
                        }
                        if (context.mounted) {
                          setState(() {
                            _isSubmitting = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Submit (${_selectedStatus})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReimbursementApprovalsView extends StatefulWidget {
  const ReimbursementApprovalsView({super.key});

  @override
  State<ReimbursementApprovalsView> createState() =>
      _ReimbursementApprovalsViewState();
}

class _ReimbursementApprovalsViewState
    extends State<ReimbursementApprovalsView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][Approvals] Screen initialized');
    _fetchApprovals();
  }

  Future<void> _fetchApprovals() async {
    debugPrint('[Reimbursement][Approvals][API] Fetch started');

    // 🛡️ Mounted guard: Don't proceed if widget already disposed
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final bool online = await NetworkHelper.hasInternet();
    if (!online) {
      AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);

      if (!mounted) return;
      setState(() {
        _requests = <Map<String, dynamic>>[];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final String? token =
          Provider.of<UserProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        debugPrint('[Reimbursement][Approvals][API] Missing token');
        // 🛡️ Mounted guard: Widget might be disposed by now
        if (mounted) {
          setState(() {
            _errorMessage = 'User token not found. Please login again.';
            _isLoading = false;
          });
        }
        return;
      }
      debugPrint('[Reimbursement][Approvals][API] Token: $token');

      final String? syncId =
          Provider.of<UserProvider>(context, listen: false).syncId;
      if (syncId == null || syncId.isEmpty) {
        debugPrint('[Reimbursement][Approvals][API] Missing syncId');
        // 🛡️ Mounted guard: Widget might be disposed by now
        if (mounted) {
          setState(() {
            _errorMessage = 'Firm information not found. Please login again.';
            _isLoading = false;
          });
        }
        return;
      }

      final Uri uri =
          Uri.parse('${AppConfig.baseURL}users/reimbursements/approvals')
              .replace(
        queryParameters: {
          'sync_Id': syncId,
        },
      );
      debugPrint('[Reimbursement][Approvals][API] GET $uri');

      final http.Response response = await http.get(
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
        '[Reimbursement][Approvals][API] Response status: ${response.statusCode}',
      );
      debugPrint(
          '[Reimbursement][Approvals][API] Response length: ${response.body.length} bytes');

      final dynamic rawData = decoded['data'];
      final List<Map<String, dynamic>> allRecords = (rawData is List)
          ? rawData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      debugPrint(
          '[Reimbursement][Approvals][API] Total records from API: ${allRecords.length}');

      if (allRecords.isNotEmpty) {
        final syncIds = allRecords.map((e) => e['SYNC_ID']).join(', ');
        debugPrint(
            '[Reimbursement][Approvals][API] SYNC_IDs in response: $syncIds');
      }

      // 🛡️ Mounted guard: Widget might be disposed during API call
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<Map<String, dynamic>> parsed = allRecords.where((e) {
          // Client-side filtering: only include records for current firm
          final recordSyncId = (e['SYNC_ID']?.toString() ?? '');
          final matches = recordSyncId == syncId;
          if (!matches) {
            debugPrint(
                '[Reimbursement][Approvals][API] Filtering out EXPENSE_ID=${e['EXPENSE_ID']}, SYNC_ID=$recordSyncId (expected $syncId)');
          }
          return matches;
        }).toList();

        setState(() {
          _requests = parsed;
          _isLoading = false;
        });
        debugPrint(
            '[Reimbursement][Approvals][API] After filtering: ${parsed.length} of ${allRecords.length} records');
      } else {
        setState(() {
          _errorMessage =
              (decoded['message'] ?? 'Failed to fetch approval reimbursements')
                  .toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Reimbursement][Approvals][API] Exception: $e');

      if (!mounted) return;

      final bool isOfflineSocketIssue =
          e is SocketException || e.toString().contains('SocketException');

      if (isOfflineSocketIssue) {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);

        setState(() {
          _requests = <Map<String, dynamic>>[];
          _errorMessage = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = 'Failed to fetch approval reimbursements';
        _isLoading = false;
      });
    }
  }

  Future<bool> _submitApprovalAction({
    required int expenseId,
    required String status,
    required String actionNote,
  }) async {
    try {
      final String? token =
          Provider.of<UserProvider>(context, listen: false).token;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User token not found. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      final Uri uri = Uri.parse(
        '${AppConfig.baseURL}users/reimbursements/$expenseId/action',
      );
      final Map<String, dynamic> payload = {
        'action': status == 'APPROVE' ? 'APPROVE' : 'REJECT',
        'note': actionNote,
      };

      debugPrint('[Reimbursement][Approvals][API] PUT $uri');
      debugPrint('[Reimbursement][Approvals][API] Action payload: $payload');

      final http.Response response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint(
        '[Reimbursement][Approvals][API] Action response status: ${response.statusCode}',
      );
      debugPrint(
        '[Reimbursement][Approvals][API] Action response body: ${response.body}',
      );

      String message = status == 'APPROVED'
          ? 'Request approved successfully'
          : 'Request rejected successfully';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      } catch (_) {}

      final bool success =
          response.statusCode >= 200 && response.statusCode < 300;

      if (!mounted) return success;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _fetchApprovals();
      }

      return success;
    } catch (e) {
      debugPrint('[Reimbursement][Approvals][API] Action exception: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit action: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _openActionBottomSheet(Map<String, dynamic> request) async {
    final int expenseId = int.tryParse('${request['EXPENSE_ID'] ?? ''}') ?? 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ApprovalActionSheet(
        expenseId: expenseId,
        onSubmit: (status, note) => _submitApprovalAction(
          expenseId: expenseId,
          status: status,
          actionNote: note,
        ),
      ),
    );
  }

// --- Move these classes to the top level of the file ---

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

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String status = (request['STATUS'] ?? 'PENDING').toString();
    final String expenseType = (request['EXPENSE_TYPE'] ?? '-').toString();
    final String amount = (request['AMOUNT'] ?? '-').toString();
    final String notes = (request['NOTES'] ?? '-').toString();

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount: ₹$amount'),
                      Text('Date: ${_formatDate(request['EXPENSE_DT'])}'),
                      const SizedBox(height: 4),
                      Text(
                        'Notes: $notes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Requester: ${(request['REQUESTER_NAME'] ?? '-').toString()}'),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openActionBottomSheet(request),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
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
                onPressed: _fetchApprovals,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(child: Text('No reimbursement approvals found.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovals,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Reimbursement][Approvals] Building screen');
    return Scaffold(
      body: _buildBody(),
    );
  }
}
