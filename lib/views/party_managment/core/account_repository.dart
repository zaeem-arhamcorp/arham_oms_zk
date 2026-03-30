import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../../../config/app_log.dart';
import '../services/api_service.dart';
import '../models/account_model.dart';

class AccountRepository extends GetxService {
  late ApiService _apiService;

  @override
  void onInit() {
    super.onInit();
    _apiService = Get.find<ApiService>();
  }

  Future<Map<String, dynamic>> createAccount(AccountModel account,
      {String? token}) async {
    try {
      final response = await _apiService.post(
        AppConfig.createAccountt,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'x-app-type': 'oms'
        },
        body: account.toJson(),
      );

      appLog('API response: $response', tag: 'AccountRepository');

      final statusCode = response['statusCode'] as int;
      final json = response['json'] as Map<String, dynamic>?;

      if (statusCode == 200 || statusCode == 201) {
        appLog('Account created successfully: $json', tag: 'AccountRepository');
        return {
          'success': true,
          'data': json,
          'message': 'Account created successfully',
        };
      } else {
        appLog('Failed to create account: $statusCode',
            tag: 'AccountRepository');
        return {
          'success': false,
          'error': 'Failed to create account: $statusCode',
          'message': json?['message'] ?? 'Failed to create account',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create account: $e',
      };
    }
  }

  // Upload image

  Future<Map<String, dynamic>> uploadImage(
      String filePath, String token) async {
    try {
      final response = await _apiService.post(
        AppConfig.uploadImage,
        headers: {'Authorization': 'Bearer $token', 'x-app-type': 'oms'},
        body: {'file': filePath},
      );

      appLog('Image upload response: $response', tag: 'AccountRepository');

      final statusCode = response['statusCode'] as int;
      final json = response['json'] as Map<String, dynamic>?;

      if (statusCode == 200 || statusCode == 201) {
        appLog('Image uploaded successfully: $json', tag: 'AccountRepository');
        return {
          'success': true,
          'data': json,
          'message': 'Image uploaded successfully',
        };
      } else {
        appLog('Failed to upload image: $statusCode', tag: 'AccountRepository');
        return {
          'success': false,
          'error': 'Failed to upload image: $statusCode',
          'message': json?['message'] ?? 'Failed to upload image',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to upload image: $e',
      };
    }
  }
}
