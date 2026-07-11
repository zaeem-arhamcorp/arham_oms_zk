import 'dart:convert';

import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:get/get.dart';

import '../../../../config/app_config.dart';
import '../../../../config/app_log.dart';
import '../../party_managment/services/api_service.dart';
import '../models/monthly_target_item_model.dart';
import '../models/monthly_target_request_model.dart';
import '../models/monthly_target_response_model.dart';

class MonthlyTargetApiService extends GetxService {
  late ApiService _apiService;

  @override
  void onInit() {
    super.onInit();
    _apiService = Get.isRegistered<ApiService>()
        ? Get.find<ApiService>()
        : Get.put(ApiService(baseUrl: AppConfig.baseURL));
  }

  Future<List<MonthlyTargetItemModel>> fetchMonthlyTargets({
    String? targetMonth,
    String? userCd,
    String? token,
  }) async {
    try {
      final queryParameters = <String, String>{
        if (targetMonth != null && targetMonth.trim().isNotEmpty)
          'targetMonth': targetMonth.trim(),
        if (userCd != null && userCd.trim().isNotEmpty) 'userCd': userCd.trim(),
      };

      final endpoint = queryParameters.isEmpty
          ? 'monthly-sales-target'
          : 'monthly-sales-target?${queryParameters.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

      final response = await _apiService.get(
        endpoint,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      final statusCode = response.statusCode;
      final body = response.body;
      appLog('Monthly target list API response: $statusCode - $body',
          tag: 'MonthlyTarget');

      if (statusCode != 200 && statusCode != 201) {
        return [];
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map>()
          .map((e) => MonthlyTargetItemModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stackTrace) {
      appLog('Monthly target list API error: $e',
          tag: 'MonthlyTarget', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<MonthlyTargetResponseModel> saveMonthlyTarget(
    MonthlyTargetRequestModel request, {
    String? token,
  }) async {
    try {
      final response = await _apiService.post(
        '${AppConfig.baseURL}monthly-sales-target',
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
        body: request.toJson(),
      );

      appLog('Monthly target API response: $response', tag: 'MonthlyTarget');

      final statusCode = response['statusCode'] as int;
      final json = response['json'] as Map<String, dynamic>?;

      if (statusCode == 200 || statusCode == 201) {
        return MonthlyTargetResponseModel.fromJson(json ?? {});
      }

      return MonthlyTargetResponseModel(
        message:
            json?['message']?.toString() ?? 'Failed to save monthly target',
        data: null,
      );
    } catch (e, stackTrace) {
      appLog('Monthly target API error: $e',
          tag: 'MonthlyTarget', error: e, stackTrace: stackTrace);
      return MonthlyTargetResponseModel(
        message: 'Failed to save monthly target: $e',
        data: null,
      );
    }
  }

  Future<bool> syncPobMonthlyTarget({
    required String stockistCd,
    required String? token,
  }) async {
    final profileProvider = Get.find<ProfileProvider>();
    if (profileProvider.data != null &&
        profileProvider.data!.modulesList!.any(
            (module) => module.mODULENO == "236" && module.rEADRIGHT == true)) {
      try {
        final userCd = _extractUserCdFromToken(token);
        if (userCd.isEmpty) {
          appLog('pob-sync skipped: userCd missing from token',
              tag: 'MonthlyTarget');
          return false;
        }

        final response = await _apiService.post(
          'monthly-sales-target/pob-sync',
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
          },
          body: {
            'targetMonth': _currentTargetMonth(),
            'stockistCd': stockistCd,
            'userCd': userCd,
          },
        );

        appLog('pob-sync response: $response', tag: 'MonthlyTarget');
        final statusCode = response['statusCode'] as int;
        return statusCode == 200 || statusCode == 201;
      } catch (e, stackTrace) {
        appLog('pob-sync API error: $e',
            tag: 'MonthlyTarget', error: e, stackTrace: stackTrace);
        return false;
      }
    } else {
      appLog('POB sync skipped: moduleNo 236 not found', tag: 'MonthlyTarget');
      return false;
    }
  }

  Future<bool> saveSecondaryTarget({
    required String targetDate, // yyyy-MM-dd
    required String stockistCd,
    String? targetDesc,
    required num secondaryAmount,
    String? token,
  }) async {
    try {
      final body = {
        'targetDate': targetDate,
        'stockistCd': stockistCd,
        'type': 'SECONDARY',
        'targetDesc': targetDesc ?? '',
        'secondaryAmount': secondaryAmount,
      };

      final response = await _apiService.post(
        '${AppConfig.baseURL}monthly-sales-target',
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
        body: body,
      );

      final statusCode = response['statusCode'] as int;
      return statusCode == 200 || statusCode == 201;
    } catch (e, stackTrace) {
      appLog('saveSecondaryTarget API error: $e',
          tag: 'MonthlyTarget', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  String _currentTargetMonth() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _extractUserCdFromToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return '';
    }

    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return '';
      }
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = decoded.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(decoded))
          : <String, dynamic>{};
      return (payload['userCd'] ??
              payload['USER_CD'] ??
              payload['user_cd'] ??
              '')
          .toString();
    } catch (e) {
      appLog('Failed to decode userCd from token: $e', tag: 'MonthlyTarget');
      return '';
    }
  }
}
