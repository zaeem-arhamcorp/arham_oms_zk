import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../models/beat_model.dart';

class BeatService {
  final String baseUrl;

  BeatService({this.baseUrl = AppConfig.baseURL});

  Future<List<dynamic>> fetchBeats({String? token}) async {
    final uri = Uri.parse('${baseUrl}beat/master');
    debugPrint('[BeatService] fetchBeats token: ${token ?? 'null'}');
    debugPrint('[BeatService] fetchBeats apiUrl: $uri');
    final sanitizedToken = token?.trim();

    final response = await http.get(uri, headers: {
      if (sanitizedToken != null && sanitizedToken.isNotEmpty)
        'Authorization': 'Bearer $sanitizedToken',
      'x-app-type': 'oms',
    });

    debugPrint('[BeatService] fetchBeats statusCode: ${response.statusCode}');
    debugPrint('[BeatService] fetchBeats response: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      return decoded?['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Failed to fetch beats: ${response.statusCode}');
  }

  /// Fetch beats scheduled for a specific user
  Future<List<dynamic>> fetchUserBeatSchedule(
      {required String userCd, String? token}) async {
    final uri = Uri.parse('${baseUrl}beat/scheduler?user_cd=$userCd');
    debugPrint('[BeatService] ${token ?? 'null'}');
    debugPrint('[BeatService] $uri');

    final response = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'x-app-type': 'oms',
    });

    debugPrint('[BeatService] statusCode: ${response.statusCode}');
    debugPrint('[BeatService] ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      return decoded?['data'] as List<dynamic>? ?? [];
    }

    throw Exception(
        'Failed to fetch user beat schedule: ${response.statusCode}');
  }

  /// Save multiple beat schedules in bulk
  Future<void> saveBeatScheduleBulk({
    required List<BeatScheduler> beatsToSave,
    String? token,
  }) async {
    final uri = Uri.parse('${baseUrl}beat/scheduler/bulk');
    final body = jsonEncode(beatsToSave.map((b) => b.toJson()).toList());

    debugPrint('[BeatService] ${token ?? 'null'}');
    debugPrint('[BeatService] $uri');
    debugPrint('[BeatService] payload: $body');

    final response = await http.post(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    debugPrint('[BeatService] ${response.statusCode}');
    debugPrint('[BeatService] response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to save beat schedule: ${response.statusCode} ${response.body}');
    }
  }

  /// Delete a beat by beat code
  Future<void> deleteBeat({required String beatCd, String? token}) async {
    final uri = Uri.parse('${baseUrl}beat/master/$beatCd');
    final sanitizedToken = token?.trim();

    debugPrint('[BeatService] deleteBeat token: ${sanitizedToken ?? 'null'}');
    debugPrint('[BeatService] deleteBeat apiUrl: $uri');

    final response = await http.delete(
      uri,
      headers: {
        if (sanitizedToken != null && sanitizedToken.isNotEmpty)
          'Authorization': 'Bearer $sanitizedToken',
        'x-app-type': 'oms',
      },
    );

    debugPrint('[BeatService] deleteBeat statusCode: ${response.statusCode}');
    debugPrint('[BeatService] deleteBeat response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete beat: ${response.statusCode}');
    }
  }

  /// Create a new beat master record
  Future<void> createBeat({
    required String beatName,
    required String moduleNo,
    required String assignUser,
    String appType = 'oms',
    String? token,
  }) async {
    final uri = Uri.parse('${baseUrl}beat/master');
    final sanitizedToken = token?.trim();

    final body = jsonEncode({
      'beatName': beatName,
      'moduleNo': moduleNo,
      'appType': appType,
      'assignUser': assignUser,
    });

    debugPrint('[BeatService] createBeat token: ${sanitizedToken ?? 'null'}');
    debugPrint('[BeatService] createBeat apiUrl: $uri');
    debugPrint('[BeatService] createBeat body: $body');

    final response = await http.post(
      uri,
      headers: {
        if (sanitizedToken != null && sanitizedToken.isNotEmpty)
          'Authorization': 'Bearer $sanitizedToken',
        'x-app-type': 'oms',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    debugPrint('[BeatService] createBeat statusCode: ${response.statusCode}');
    debugPrint('[BeatService] createBeat response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create beat: ${response.statusCode}');
    }
  }

  /// Update an existing beat master record
  Future<void> updateBeat({
    required String beatCd,
    required String beatName,
    required String moduleNo,
    required String assignUser,
    String appType = 'oms',
    String? token,
  }) async {
    final uri = Uri.parse('${baseUrl}beat/master/$beatCd');
    final sanitizedToken = token?.trim();

    final body = jsonEncode({
      'beatName': beatName,
      'moduleNo': moduleNo,
      'appType': appType,
      'assignUser': assignUser,
    });

    debugPrint('[BeatService] updateBeat token: ${sanitizedToken ?? 'null'}');
    debugPrint('[BeatService] updateBeat apiUrl: $uri');
    debugPrint('[BeatService] updateBeat body: $body');

    final response = await http.put(
      uri,
      headers: {
        if (sanitizedToken != null && sanitizedToken.isNotEmpty)
          'Authorization': 'Bearer $sanitizedToken',
        'x-app-type': 'oms',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    debugPrint('[BeatService] updateBeat statusCode: ${response.statusCode}');
    debugPrint('[BeatService] updateBeat response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update beat: ${response.statusCode}');
    }
  }

  /// Fetch children users for assignment
  Future<List<Map<String, dynamic>>> fetchChildren({String? token}) async {
    try {
      final sanitizedToken = token?.trim();
      var authToken = sanitizedToken ?? '';
      if (!authToken.startsWith('Bearer ')) {
        authToken = 'Bearer $authToken';
      }

      final uri = Uri.parse('${baseUrl}users/children').replace(
        queryParameters: {
          'date': DateTime.now().toString().split(' ')[0], // YYYY-MM-DD format
          'page': '1',
          'items_per_page': '100',
        },
      );

      debugPrint('[BeatService] ${sanitizedToken ?? 'null'}');
      debugPrint('[BeatService] GET $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': authToken,
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[BeatService] ${response.statusCode}');
      debugPrint('[BeatService] ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> childrenList = jsonData['data'] ?? [];
        return childrenList.whereType<Map>().map((child) {
          final normalized = Map<String, dynamic>.from(child);
          return {
            'userCode': (normalized['USER_CD'] ?? '').toString().trim(),
            'userName': (normalized['USER_NAME'] ?? '').toString().trim(),
            'phone': (normalized['MOBILENO'] ?? '').toString().trim(),
          };
        }).toList();
      } else {
        throw Exception('Failed to fetch children: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[BeatService] fetchChildren error: $e');
      rethrow;
    }
  }

  /// Fetch single beat details by beat code
  Future<Map<String, dynamic>> fetchBeatByCode({
    required String beatCd,
    String? token,
  }) async {
    try {
      final sanitizedToken = token?.trim();
      var authToken = sanitizedToken ?? '';
      if (!authToken.startsWith('Bearer ') && authToken.isNotEmpty) {
        authToken = 'Bearer $authToken';
      }

      final uri = Uri.parse('${baseUrl}beat/master/$beatCd');

      debugPrint(
          '[BeatService] fetchBeatByCode token: ${sanitizedToken ?? 'null'}');
      debugPrint('[BeatService] fetchBeatByCode apiUrl: $uri');

      final response = await http.get(
        uri,
        headers: {
          if (authToken.isNotEmpty) 'Authorization': authToken,
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[BeatService] fetchBeatByCode statusCode: ${response.statusCode}');
      debugPrint('[BeatService] fetchBeatByCode response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonData['data'] as Map<String, dynamic>?;
        return data ?? <String, dynamic>{};
      }

      throw Exception('Failed to fetch beat: ${response.statusCode}');
    } catch (e) {
      debugPrint('[BeatService] fetchBeatByCode error: $e');
      rethrow;
    }
  }
}
