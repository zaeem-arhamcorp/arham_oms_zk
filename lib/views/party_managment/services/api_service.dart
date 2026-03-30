import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/app_log.dart';


class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<http.Response> get(String endpoint,
      {Map<String, String>? headers}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    return await http.get(url, headers: mergedHeaders);
  }

  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, String>? headers, Object? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final mergedHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    try {
      final response =
          await http.post(url, headers: mergedHeaders, body: jsonEncode(body));

      appLog(
          'API POST request to $url with body: $body and headers: $mergedHeaders',
          tag: 'ApiService');
      return {
        'statusCode': response.statusCode,
        'body': response.body,
        'json': response.body.isNotEmpty ? jsonDecode(response.body) : null,
      };


    } catch (e, stackTrace) {
      // Log the error
      // ignore: avoid_print
      appLog('API POST error: $e',
          tag: 'ApiService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
