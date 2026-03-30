import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/app_log.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../models/account_model.dart';
import '../core/account_repository.dart';
import '../widgets/account_form_fields.dart';

class AccountController extends GetxController {
  final RxBool isLocationLoading = false.obs;
  final RxString latitudeRx = ''.obs;
  final RxString longitudeRx = ''.obs;
  final AccountRepository _repository = Get.find<AccountRepository>();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  final RxBool isLicensedVisible = false.obs;

  final Rx<File?> selectedImage = Rx<File?>(null);
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final locationProvider =
      Provider.of<LocationProvider>(Get.context!, listen: false);

  @override
  void onClose() {
    appLog('onClose called', tag: 'AccountController');
    AccountFormFields.clearAll();
    super.onClose();
  }

  void toggleLicenseFields(bool value) {
    isLicensedVisible.value = value;
    appLog('toggleLicenseFields called with value: $value',
        tag: 'AccountController');
  }

  Future<void> pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
        appLog('Image selected: ${pickedFile.path}', tag: 'AccountController');
      } else {
        appLog('No image selected', tag: 'AccountController');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image');
      appLog('Image pick error: $e', tag: 'AccountController');
    }
  }

  // Remove image
  void removeImage() {
    selectedImage.value = null;
    appLog('Image removed', tag: 'AccountController');
  }

  void updateLocationFields() async {
    isLocationLoading.value = true;
    await locationProvider.getCurrentLocation();
    final latitude = locationProvider.lat;
    final longitude = locationProvider.lag;
    appLog('Updating location fields: lat=$latitude, long=$longitude',
        tag: 'AccountController');
    AccountFormFields.latitudeController.text = latitude.toString();
    AccountFormFields.longitudeController.text = longitude.toString();
    isLocationLoading.value = false;
  }

  Future<void> createAccountFromForm(BuildContext context) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      successMessage.value = '';

      // Ensure location fields are up to date before submit
      updateLocationFields();

      final account = AccountModel(
        accName: AccountFormFields.accNameController.text.trim(),
        personNm: AccountFormFields.personNmController.text.trim(),
        mobile1: AccountFormFields.mobile1Controller.text.trim(),
        add1: AccountFormFields.add1Controller.text.trim(),
        city: AccountFormFields.cityController.text.trim(),
        // state: AccountFormFields.stateController.text.trim(),
        // pincode: AccountFormFields.pincodeController.text.trim(),
        latitude:
            double.tryParse(AccountFormFields.latitudeController.text) ?? 0.0,
        longitude:
            double.tryParse(AccountFormFields.longitudeController.text) ?? 0.0,
        // 🔹 License fields (only if visible)
        gstNo: isLicensedVisible.value
            ? AccountFormFields.gstNoController.text.trim()
            : '',
        gstType: AccountFormFields.gstNoController.text.trim().isNotEmpty
            ? 'R'
            : 'U',
        drugLic1: isLicensedVisible.value
            ? AccountFormFields.drugLic1Controller.text.trim()
            : '',
        drugLic2: isLicensedVisible.value
            ? AccountFormFields.drugLic2Controller.text.trim()
            : '',
        fssaiNo: isLicensedVisible.value
            ? AccountFormFields.fssaiNoController.text.trim()
            : '',
      );

      // appLog('data  ${account.toJson()}');

      // Get token from UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      final result = await _repository.createAccount(account, token: token);

      if (result['success']) {
        successMessage.value = result['message'];
        final accName = AccountFormFields.accNameController.text.trim();
        AccountFormFields.clearAll();
        // Pop and pass account name back
        Get.back(result: accName);
      } else {
        errorMessage.value = result['error'];
      }
    } catch (e, stackTrace) {
      errorMessage.value = 'Error: $e';
      appLog(
        'Exception in createAccountFromForm: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading.value = false;
      appLog('Loading state set to false', tag: 'AccountController');
      appLog('createAccountFromForm completed', tag: 'AccountController');
    }
  }

  void showImageSourcePicker() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Get.back();
                pickImage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Get.back();
                pickImage(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
