import 'dart:io';

import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../../../config/app_log.dart';
import '../models/account_model.dart';
import '../services/api_service.dart';

class AccountRepository extends GetxService {
  late ApiService _apiService;

  @override
  void onInit() {
    super.onInit();
    _apiService = Get.isRegistered<ApiService>()
        ? Get.find<ApiService>()
        : Get.put(ApiService(baseUrl: AppConfig.baseURL));
  }

  Future<Map<String, dynamic>> createAccount(AccountModel account,
      {String? token}) async {
    try {
      final response = await _apiService.post(
        AppConfig.createAccounttURL,
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
        AppConfig.uploadImageURL,
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

  // Upload account image with ACC_CD
  Future<Map<String, dynamic>> uploadAccountImage({
    required String accCd,
    required File imageFile,
    required String token,
  }) async {
    try {
      appLog(
        '[uploadAccountImage] Starting upload - accCd: $accCd, file: ${imageFile.path}',
        tag: 'AccountRepository',
      );

      final response = await _apiService.postMultipart(
        AppConfig.uploadAccountImageURL,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
        fields: {
          'accCd': accCd,
        },
        files: {
          'image': imageFile,
        },
      );

      appLog('[uploadAccountImage] Response: $response',
          tag: 'AccountRepository');

      final statusCode = response['statusCode'] as int;
      final json = response['json'] as Map<String, dynamic>?;

      if (statusCode == 200 || statusCode == 201) {
        appLog('[uploadAccountImage] Success: $json', tag: 'AccountRepository');
        return {
          'success': true,
          'data': json,
          'message': 'Account image uploaded successfully',
        };
      } else {
        appLog('[uploadAccountImage] Failed with status: $statusCode',
            tag: 'AccountRepository');
        return {
          'success': false,
          'error': 'Failed to upload account image: $statusCode',
          'message': json?['message'] ?? 'Failed to upload account image',
        };
      }
    } catch (e) {
      appLog('[uploadAccountImage] Exception: $e',
          tag: 'AccountRepository', error: e);
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to upload account image: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateAccount({
    required AccountModel account,
    required String accCode,
    required double latitude,
    required double longitude,
    required String? token,
  }) async {
    try {
      final response = await _apiService.put(
        AppConfig.baseURL + 'master-entry/account', // or create a constant
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
        body: {
          /// 🔑 REQUIRED FIELD
          "accCd": accCode,

          /// 🔹 From your model
          ...account.toJson(includeLocation: false),

          /// 🔒 FORCE LAT/LONG (no override allowed)
          "latitude": latitude,
          "longitude": longitude,

          /// 🔹 Optional fields (safe defaults)
          "add2": "",
          "add3": "",
          "mobile2": "",
          "email": "",
          "panNo": "",
          "accKm": 0,
          "age": 0,
          "clBal": 0,
          "crLimit": 0,
          "creditDay": 0,
          "depriPerc": 0,
          "groupCd": 85,
          "blackList": "N",
          "moduleNo": 102,
          "lat": latitude,
          "lng": longitude,
        },
      );

      appLog('Update API response: $response', tag: 'AccountRepository');

      final statusCode = response['statusCode'] as int;
      final json = response['json'] as Map<String, dynamic>?;

      if (statusCode == 200 || statusCode == 201) {
        return {
          'success': true,
          'data': json,
          'message': json?['message'] ?? 'Account updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update account: $statusCode',
          'message': json?['message'] ?? 'Update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update account: $e',
      };
    }
  }
}
