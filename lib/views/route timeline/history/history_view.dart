import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../items/items_view.dart';

class HistoryView extends StatefulWidget {
  final String userCode;
  final String partyCode;
  final String partyName;
  final String token;

  const HistoryView({
    super.key,
    required this.userCode,
    required this.partyCode,
    required this.partyName,
    required this.token,
  });

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  String _filterType = 'All';
  DateTime _toDate = DateTime.now();
  late DateTime _fromDate;

  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = false;
  String? _loadError;
  int _requestCounter = 0;

  @override
  void initState() {
    super.initState();
    _fromDate = _toDate.subtract(const Duration(days: 10));
    _loadHistory();
  }

  DateTime _parseDateTime(Map<String, dynamic> record, bool isProductive) {
    final dateStr = (record['VOUCH_DT'] ?? '').toString().trim();
    final timeStr = isProductive
        ? (() {
            final items = record['ordritms'] as List?;
            if (items == null || items.isEmpty) return '';
            final firstItem = items.first as Map?;
            return (firstItem?['VOUCH_TIME'] ?? '').toString().trim();
          })()
        : (record['IN_TIME'] ?? '').toString().trim();

    DateTime parsedDate;
    try {
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts[0].length == 4) {
          parsedDate = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          parsedDate = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts[2].length == 4) {
          parsedDate = DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else {
          parsedDate = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } else {
        parsedDate = DateTime.tryParse(dateStr) ?? DateTime(1970);
      }
    } catch (_) {
      parsedDate = DateTime(1970);
    }

    int hour = 0;
    int minute = 0;
    try {
      if (timeStr.isNotEmpty) {
        final cleanTime = timeStr.toUpperCase();
        if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
          final parts =
              cleanTime.replaceAll(RegExp(r'[AM|PM|\s]'), '').split(':');
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1]);
          if (cleanTime.contains('PM') && hour < 12) {
            hour += 12;
          } else if (cleanTime.contains('AM') && hour == 12) {
            hour = 0;
          }
        } else {
          final parts = cleanTime.split(':');
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1]);
        }
      }
    } catch (_) {}

    return DateTime(
        parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
  }

  Future<void> _loadHistory() async {
    final requestId = ++_requestCounter;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      List<Map<String, dynamic>> records = [];

      if (_filterType == 'All') {
        final results = await Future.wait([
          _fetchProductiveHistory(),
          _fetchNonProductiveHistory(),
        ]);

        final prod =
            results[0].map((e) => {...e, '_recordType': 'Productive'}).toList();
        final nonProd = results[1]
            .map((e) => {...e, '_recordType': 'Non Productive'})
            .toList();

        records = [...prod, ...nonProd];

        records.sort((a, b) {
          final dtA = _parseDateTime(a, a['_recordType'] == 'Productive');
          final dtB = _parseDateTime(b, b['_recordType'] == 'Productive');
          return dtB.compareTo(dtA);
        });
      } else if (_filterType == 'Productive') {
        final raw = await _fetchProductiveHistory();
        records = raw.map((e) => {...e, '_recordType': 'Productive'}).toList();
      } else {
        final raw = await _fetchNonProductiveHistory();
        records =
            raw.map((e) => {...e, '_recordType': 'Non Productive'}).toList();
      }

      if (!mounted || requestId != _requestCounter) return;

      setState(() {
        _historyData = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestCounter) return;
      setState(() {
        _historyData = [];
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _fetchProductiveHistory() async {
    final uri = Uri.parse('${AppConfig.baseURL}reports/orders')
        .replace(queryParameters: {
      'userCd': widget.userCode,
      'fromDate': _fmtDate(_fromDate),
      'toDate': _fmtDate(_toDate),
      'partyCd': widget.partyCode,
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'x-app-type': 'oms',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load history: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchNonProductiveHistory() async {
    final uri = Uri.parse('${AppConfig.baseURL}orders-tracking')
        .replace(queryParameters: {
      'non_productive': 'true',
      'user_cd': widget.userCode,
      'fromDate': _fmtDate(_fromDate),
      'toDate': _fmtDate(_toDate),
      'party_cd': widget.partyCode,
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'x-app-type': 'oms',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load non-productive history: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Party History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadHistory,
            icon: Icon(
              Icons.refresh,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildPartyNameSection(isDark),
            _buildFiltersSection(isDark),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyNameSection(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: widget.partyName.isNotEmpty || widget.partyCode.isNotEmpty
                ? Text(
                    widget.partyName.isNotEmpty
                        ? widget.partyName
                        : 'Code: ${widget.partyCode}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  )
                : SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Filter type chips
          Row(
            children: [
              _filterChip(
                label: 'All',
                icon: Icons.list_alt,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Productive',
                icon: Icons.trending_up,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Non-Prod',
                icon: Icons.trending_down,
                color: const Color(0xFFF97316),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date pickers
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  label: 'From Date',
                  date: _fromDate,
                  isDark: isDark,
                  showTodayIcon: true,
                  onTodayTap: () {
                    final today = DateTime.now();
                    setState(() {
                      _fromDate = DateTime(today.year, today.month, today.day);
                    });
                    _loadHistory();
                  },
                  onTap: () {
                    DatePicker.showDatePicker(
                      context,
                      showTitleActions: true,
                      minTime: DateTime(2000, 1, 1),
                      maxTime: _toDate,
                      currentTime: _fromDate,
                      locale: LocaleType.en,
                      onConfirm: (date) {
                        if (!mounted) return;
                        setState(() {
                          _fromDate = DateTime(date.year, date.month, date.day);
                        });
                        _loadHistory();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePickerField(
                  label: 'To Date',
                  date: _toDate,
                  isDark: isDark,
                  onTap: () {
                    DatePicker.showDatePicker(
                      context,
                      showTitleActions: true,
                      minTime: DateTime(2000, 1, 1),
                      maxTime: DateTime(2100, 12, 31),
                      currentTime: _toDate,
                      locale: LocaleType.en,
                      onConfirm: (date) {
                        if (!mounted) return;
                        setState(() {
                          _toDate = DateTime(date.year, date.month, date.day);
                        });
                        _loadHistory();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _filterType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_filterType == label) return;
          setState(() => _filterType = label);
          _loadHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.12)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected
                      ? color
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? color
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime date,
    required bool isDark,
    required VoidCallback onTap,
    bool showTodayIcon = false,
    VoidCallback? onTodayTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.12),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixIcon: showTodayIcon
              ? GestureDetector(
                  onTap: onTodayTap,
                  child: Tooltip(
                    message: 'Reset to today',
                    child: Icon(
                      Icons.today_outlined,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                )
              : null,
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _buildError(isDark);
    }
    if (_historyData.isEmpty) {
      return _buildEmptyState(isDark);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _historyData.length,
      itemBuilder: (context, index) =>
          _buildHistoryCard(_historyData[index], isDark),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record, bool isDark) {
    final date = (record['VOUCH_DT'] ?? '').toString();
    final recordType = record['_recordType'] ?? _filterType;
    final isProductive = recordType == 'Productive';

    final inTime = isProductive
        ? (() {
            final items = record['ordritms'] as List?;
            if (items == null || items.isEmpty) return '';
            final firstItem = items.first as Map?;
            return (firstItem?['VOUCH_TIME'] ?? '').toString();
          })()
        : (record['IN_TIME'] ?? '').toString();

    final outTime = isProductive ? '' : (record['OUT_TIME'] ?? '').toString();

    final amount =
        isProductive ? ((record['NET_AMT'] ?? record['OR_AMT']) ?? 0) : null;

    final reason = !isProductive ? (record['REASON'] ?? '').toString() : '';
    final narration = isProductive ? (record['NARRATION'] ?? record['narration'] ?? '').toString() : '';

    final amountDouble = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isProductive
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemsView(
                        items: List<Map<String, dynamic>>.from(
                            record['ordritms'] ?? []),
                        partyName: widget.partyName,
                        partyCode: widget.partyCode,
                        partyAddress: '',
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Date & time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          if (inTime.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  outTime.isNotEmpty
                                      ? '$inTime – $outTime'
                                      : inTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Right: badge + amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isProductive
                                ? const Color(0xFF10B981).withOpacity(0.12)
                                : const Color(0xFFF97316).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            recordType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isProductive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF97316),
                            ),
                          ),
                        ),
                        if (amount != null /*&& amountDouble > 0*/) ...[
                          const SizedBox(height: 4),
                          Text(
                            '₹${Helper.parseNumericValue(amount.toString())}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isProductive) ...[
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          narration.isNotEmpty ? 'Narration: $narration' : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 9,
                            color: const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color:
                    isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Failed to load history',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 56,
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'No Records Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _filterType == 'All'
                ? 'No history records in the selected date range.'
                : 'No $_filterType records in the selected date range.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
