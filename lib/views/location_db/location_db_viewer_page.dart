import 'package:arham_corporation/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationDbViewerPage extends StatefulWidget {
  const LocationDbViewerPage({super.key});

  @override
  State<LocationDbViewerPage> createState() => _LocationDbViewerPageState();
}

class _LocationDbViewerPageState extends State<LocationDbViewerPage> {
  final DatabaseHelper _db = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _trackingFuture;
  late Future<List<Map<String, dynamic>>> _onDemandFuture;
  late Future<List<Map<String, dynamic>>> _sharedPrefsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _trackingFuture = _db.getAllLocationTracking();
    _onDemandFuture = _db.getAllLocationOnDemand();
    _sharedPrefsFuture = _getSharedPrefsData();
  }

  Future<List<Map<String, dynamic>>> _getSharedPrefsData() async {
    final prefs = await SharedPreferences.getInstance();

    final keys = prefs.getKeys().toList()..sort();

    print('\n===== SHARED PREFERENCES =====');
    for (final key in prefs.getKeys().toList()..sort()) {
      final value = prefs.get(key);
      print('[$key] (${value.runtimeType}) = $value');
    }
    print('==============================\n');

    return keys.map((key) {
      return {
        'key': key,
        'value': prefs.get(key)?.toString() ?? '',
        'type': prefs.get(key)?.runtimeType.toString() ?? '',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Location DB'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(_reload);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Location Tracking'),
              Tab(text: 'On-Demand'),
              Tab(text: 'SharedPref'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTableFuture(
              future: _trackingFuture,
              columns: const [
                'id',
                'latitude',
                'longitude',
                'timestamp',
                'synced',
                'sync_status',
                'user_cd',
                'sync_id',
                'trip_id',
                'accuracy',
                'speed',
                'altitude',
                'activity_type',
                'created_at',
              ],
              emptyMessage: 'No location_tracking rows found.',
            ),
            _buildTableFuture(
              future: _onDemandFuture,
              columns: const [
                'id',
                'party_id',
                'latitude',
                'longitude',
                'timestamp',
                'activity_type',
                'stored_at',
                'synced',
              ],
              emptyMessage: 'No location_on_demand rows found.',
            ),
            _buildTableFuture(
              future: _sharedPrefsFuture,
              columns: const [
                'key',
                'value',
                'type',
              ],
              emptyMessage: 'No SharedPreferences found.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableFuture({
    required Future<List<Map<String, dynamic>>> future,
    required List<String> columns,
    required String emptyMessage,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return _buildTable(columns, rows);
      },
    );
  }

  Widget _buildTable(List<String> columns, List<Map<String, dynamic>> rows) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns:
                columns.map((col) => DataColumn(label: Text(col))).toList(),
            rows: rows.map((row) {
              return DataRow(
                cells: columns.map((col) {
                  final value = row[col];
                  return DataCell(Text(_formatCellValue(col, value)));
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatCellValue(String column, dynamic value) {
    if (value == null) return '';
    if (_isTimestampColumn(column)) {
      final int? millis = _toMillis(value);
      if (millis != null) {
        return _formatDateTime(millis);
      }
    }
    return '$value';
  }

  bool _isTimestampColumn(String column) {
    return column.contains('timestamp') || column.endsWith('_at');
  }

  int? _toMillis(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatDateTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min:$ss';
  }
}
