
import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:cancellation_token_http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class ChangePasswordController extends GetxController {
  var isLoading = false.obs;
  var isDisable = false.obs;

  var oldPasswordController = TextEditingController().obs;
  var newPasswordController = TextEditingController().obs;
  var confirmPasswordController = TextEditingController().obs;

  var oldPasswordFocus = FocusNode();
  var newPasswordFocus = FocusNode();
  var confirmPassWordFocus = FocusNode();

  var isOldPasswordObscured = true.obs;
  var isNewPasswordObscured = true.obs;
  var isConfirmPasswordObscured = true.obs;

  void oldPassToggleObscured() {
    isOldPasswordObscured.value = !isOldPasswordObscured.value;
  }

  void newPassToggleObscured() {
    isNewPasswordObscured.value = !isNewPasswordObscured.value;
  }

  void confirmPassToggleObscured() {
    isConfirmPasswordObscured.value = !isConfirmPasswordObscured.value;
  }

  @override
  void onClose() {
    // TODO: implement onClose
    oldPasswordController.value.dispose();
    newPasswordController.value.dispose();
    confirmPasswordController.value.dispose();
    super.onClose();
  }

  void validationWithAPI() {
    if (oldPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter old password.');
    } else if (newPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter new password.');
    } else if (confirmPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter confirm password.');
    } else if (confirmPasswordController.value.text !=
        newPasswordController.value.text) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Confirm Password & New Password Not Match.');
    } else {
      insertUpdateUser(
        oldPasswordController.value.text,
        newPasswordController.value.text,
      );
    }
  }

  Future<void> insertUpdateUser(
      String oldPassword,
      String newPassword,
      ) async {
    final url = Uri.parse(AppConfig.changePasswordURL);

    try {
      final UserProvider ub =
      Provider.of<UserProvider>(Get.context!, listen: false);

      Map<String, dynamic> payload = {
        "oldPassword": oldPassword,
        "newPassword": newPassword,
      };

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token!}",
          'Content-Type': 'application/json',
          'x-app-type': 'oms',
        },
        body: jsonEncode(payload),
      );

      print('URL $url');
      print('Body $payload');
      print('Response $response');

      if (response.statusCode == 200 || response.statusCode == 201) {
        ub.userSignout(Get.context!).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
                'Failed to change password: ${response.statusCode} - ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text('An error occurred: ${e.toString()}')),
      );
    }
  }
}
