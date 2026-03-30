import 'package:get/get.dart';

import '../../../config/app_config.dart';
import '../controllers/account_controller.dart';
import '../core/account_repository.dart';
import '../services/api_service.dart';

class AccountBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApiService>(() => ApiService(baseUrl: AppConfig.baseURL));
    Get.lazyPut<AccountRepository>(() => AccountRepository());
    Get.lazyPut<AccountController>(() => AccountController());
  }
}
