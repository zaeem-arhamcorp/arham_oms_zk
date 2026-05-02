import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../models/beat_model.dart';

class BeatService {
  final String baseUrl;

  BeatService({this.baseUrl = AppConfig.baseURL});

  Future<List<dynamic>> fetchBeats({String? token}) async {
    final uri = Uri.parse('${baseUrl}beat/master');
    final response = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'x-app-type': 'oms',
    });

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      return decoded?['data'] as List<dynamic>? ?? [];
    }

    throw Exception('Failed to fetch beats: ${response.statusCode}');
  }

  /// Fetch beats scheduled for a specific user
  Future<List<dynamic>> fetchUserBeatSchedule(
      {required String userCd, String? token}) async {
    final uri = Uri.parse('${baseUrl}beat/scheduler?userCd=$userCd');
    final response = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'x-app-type': 'oms',
    });

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

    final response = await http.post(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to save beat schedule: ${response.statusCode} ${response.body}');
    }
  }
}
