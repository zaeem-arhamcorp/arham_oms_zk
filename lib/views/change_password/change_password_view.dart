import 'package:arham_corporation/views/change_password/change_password_controller.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePasswordView extends StatefulWidget {
  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  ChangePasswordController controller = Get.put(ChangePasswordController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Change Password',
      ),
      body: SafeArea(
        child: Obx(() => Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Expanded(child: _getView(context)),
                  CommonButton(
                          buttonText: 'Submit',
                          onPressed: () {
                            controller.validationWithAPI();
                          },
                          isLoading: controller.isLoading.value,
                          isDisable: controller.isDisable.value)
                      .paddingOnly(top: 10),
                ],
              ),
            )),
      ),

      // body: SafeArea(
      //   child: Obx(() => Container(
      //     padding: const EdgeInsets.all(16),
      //     child: _addTaxView(context),
      //   )),
      // ),
    );
  }

  Widget _getView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommonAppInput(
            maxLines: 1,
            suffixIcon: controller.isOldPasswordObscured.value
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            onSubmitted: (val) {
              FocusScope.of(context).requestFocus(controller.newPasswordFocus);
            },
            onSuffixClick: () => controller.oldPassToggleObscured(),
            textInputAction: TextInputAction.next,
            textEditingController: controller.oldPasswordController.value,
            hintText: "Old Password",
            maxLength: 12,
            focusNode: controller.oldPasswordFocus,
            isPassword: controller.isOldPasswordObscured.value ? true : false,
            nextFocusNode: controller.newPasswordFocus,
          ),
          SizedBox(height: 10,),
          CommonAppInput(
            maxLines: 1,
            suffixIcon: controller.isNewPasswordObscured.value
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            onSubmitted: (val) {
              FocusScope.of(context)
                  .requestFocus(controller.confirmPassWordFocus);
            },
            onSuffixClick: () => controller.newPassToggleObscured(),
            textInputAction: TextInputAction.next,
            textEditingController: controller.newPasswordController.value,
            hintText: "Password",
            maxLength: 12,
            focusNode: controller.newPasswordFocus,
            isPassword: controller.isNewPasswordObscured.value ? true : false,
            nextFocusNode: controller.confirmPassWordFocus,
          ),
          SizedBox(height: 10,),
          CommonAppInput(
            maxLines: 1,
            textInputAction: TextInputAction.done,
            suffixIcon: controller.isConfirmPasswordObscured.value
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            maxLength: 12,
            onSuffixClick: () => controller.confirmPassToggleObscured(),
            textEditingController: controller.confirmPasswordController.value,
            hintText: "Confirm Password",
            focusNode: controller.confirmPassWordFocus,
            isPassword:
                controller.isConfirmPasswordObscured.value ? true : false,
          ),
        ],
      ),
    );
  }
}
