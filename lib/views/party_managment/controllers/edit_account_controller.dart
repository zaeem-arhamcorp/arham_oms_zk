import 'package:arham_corporation/views/party_managment/controllers/account_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../../product/widget/app_snack_bar.dart';
import '../../../providers/party_provider.dart';
import '../../../providers/user_provider.dart';
import '../core/account_repository.dart';
import '../models/account_model.dart';
import '../widgets/account_form_fields.dart';

class EditAccountController extends AccountController {
  final RxBool isLoading = false.obs;
  final RxBool isLicensedVisible = false.obs;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final AccountRepository _repository = Get.isRegistered<AccountRepository>()
      ? Get.find<AccountRepository>()
      : Get.put(AccountRepository());

  /// 🔑 Required for update
  String accCode = '';

  /// 🔒 LOCKED LAT/LONG
  double fixedLatitude = 0.0;
  double fixedLongitude = 0.0;

  @override
  void onInit() {
    locationLocked = true;
    super.onInit();
  }

  /// =========================
  /// PREFILL DATA
  /// =========================
  void prefill(Map<String, dynamic> data) {
    print(
        '📝 [EditAccountController] prefill() called with ACC_CD=${data['ACC_CD']}, ACC_NAME=${data['ACC_NAME']}');

    accCode = data['ACC_CD'] ?? '';

    AccountFormFields.accNameController.text = data['ACC_NAME'] ?? '';
    AccountFormFields.personNmController.text = data['PERSON_NM'] ?? '';
    AccountFormFields.mobile1Controller.text = data['MOBILE1'] ?? '';

    AccountFormFields.add1Controller.text = data['ADD1'] ?? '';
    AccountFormFields.areaController.text = data['ZONE'] ?? '';
    AccountFormFields.cityController.text = data['CITY'] ?? '';
    AccountFormFields.stateController.text = data['STATE'] ?? '';
    AccountFormFields.pincodeController.text = data['PINCODE'] ?? '';
    AccountFormFields.whatsappNoController.text = data['WA_NO'] ?? '';
    AccountFormFields.emailController.text = data['EMAIL'] ?? '';
    AccountFormFields.userController.text = data['USER_CD'] ?? '';

    // Beat code (may come as BEAT_CD or beatCd)
    AccountFormFields.beatCdController.text =
        (data['BEAT_CD'] ?? data['beatCd'] ?? '').toString();

    /// 🔒 LOCK LAT/LONG FROM API
    fixedLatitude =
        double.tryParse((data['LATITUDE'] ?? '0').toString()) ?? 0.0;
    fixedLongitude =
        double.tryParse((data['LONGITUDE'] ?? '0').toString()) ?? 0.0;

    seedLockedLocation(fixedLatitude, fixedLongitude);

    /// License
    final gstNo = data['GST_NO'] ?? '';
    AccountFormFields.gstNoController.text = gstNo;
    AccountFormFields.drugLic1Controller.text = data['DRUG_LIC1'] ?? '';
    AccountFormFields.drugLic2Controller.text = data['DRUG_LIC2'] ?? '';
    AccountFormFields.fssaiNoController.text = data['FSSAI_NO'] ?? '';

    isLicensedVisible.value = gstNo.toString().isNotEmpty;

    print(
        '✅ [EditAccountController] prefill() completed - accNameController.text="${AccountFormFields.accNameController.text}"');
  }

  void toggleLicenseFields(bool value) {
    isLicensedVisible.value = value;
  }

  /// =========================
  /// UPDATE ACCOUNT API
  /// =========================
  Future<void> updateAccount(BuildContext context) async {
    try {
      isLoading.value = true;

      final account = AccountModel(
        accName: AccountFormFields.accNameController.text.trim(),
        personNm: AccountFormFields.personNmController.text.trim(),
        mobile1: AccountFormFields.mobile1Controller.text.trim(),
        add1: AccountFormFields.add1Controller.text.trim(),
        area: AccountFormFields.areaController.text.trim(),
        city: AccountFormFields.cityController.text.trim(),
        state: AccountFormFields.stateController.text.trim(),
        pincode: AccountFormFields.pincodeController.text.trim(),
        beatCd: AccountFormFields.beatCdController.text.trim(),
        whatsappNo: AccountFormFields.whatsappNoController.text.trim(),
        email: AccountFormFields.emailController.text.trim(),
        userCd: AccountFormFields.userController.text.trim(),

        /// 🔒 STRICTLY FIXED
        latitude: fixedLatitude,
        longitude: fixedLongitude,

        gstNo: AccountFormFields.gstNoController.text.trim(),
        gstType: AccountFormFields.gstNoController.text.trim().isNotEmpty
            ? 'R'
            : 'U',
        drugLic1: AccountFormFields.drugLic1Controller.text.trim(),
        drugLic2: AccountFormFields.drugLic2Controller.text.trim(),
        fssaiNo: AccountFormFields.fssaiNoController.text.trim(),
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final result = await _repository.updateAccount(
        account: account,
        accCode: accCode,
        latitude: fixedLatitude,
        longitude: fixedLongitude,
        token: userProvider.token,
      );

      if (result['success']) {
        // ✅ Update the party data in PartyProvider with the latest API response
        // This ensures that when the edit screen closes and reopens,
        // prefill() will have the updated data from the server
        if (result['data'] != null && result['data']['data'] != null) {
          try {
            final partyProvider =
                Provider.of<PartyProvider>(context, listen: false);
            final updatedData = result['data']['data'] as Map<String, dynamic>;
            print(result['data']);
            print(result['data']['data'].runtimeType);
            print(result['data']['data']);
            partyProvider.updatePartyData(accCode, updatedData);
          } catch (e) {
            print('❌ Error updating PartyProvider: $e');
          }
        }

        AppSnackBar.showGetXCustomSnackBar(
          message: 'Account updated successfully',
          backgroundColor: Colors.green,
        );
        Get.back(result: true);
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message: result['error']?.toString() ?? 'Update failed',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Something went wrong',
        backgroundColor: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
