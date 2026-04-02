import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

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

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    Map<String, File>? files,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);

    // Add headers
    request.headers.addAll(headers ?? {});

    // Add fields
    if (fields != null) {
      request.fields.addAll(fields);
    }

    // Add files
    if (files != null) {
      for (var entry in files.entries) {
        final file = entry.value;
        final fieldName = entry.key;
        final fileName = file.path.split('/').last;
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';

        appLog('Attaching file: $fieldName -> $fileName ($mimeType)',
            tag: 'ApiService');

        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            file.path,
            filename: fileName,
            contentType: _parseMediaType(mimeType),
          ),
        );
      }
    }

    try {
      appLog('API MULTIPART POST request to $url', tag: 'ApiService');
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      appLog('API MULTIPART response status: ${response.statusCode}',
          tag: 'ApiService');
      appLog('API MULTIPART response body: $responseBody', tag: 'ApiService');

      return {
        'statusCode': response.statusCode,
        'body': responseBody,
        'json': responseBody.isNotEmpty ? jsonDecode(responseBody) : null,
      };
    } catch (e, stackTrace) {
      appLog('API MULTIPART POST error: $e',
          tag: 'ApiService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Helper to parse media type
  dynamic _parseMediaType(String mimeType) {
    try {
      final parts = mimeType.split('/');
      if (parts.length == 2) {
        return http.MediaType(parts[0], parts[1]);
      }
    } catch (e) {
      appLog('Error parsing MIME type: $e', tag: 'ApiService');
    }
    return http.MediaType('application', 'octet-stream');
  }
}
