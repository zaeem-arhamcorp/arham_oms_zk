import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/account_controller.dart';
import '../widgets/form_widgets.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AccountController>();
    controller.updateLocationFields();

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Account Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormWidgets.basicInfo(controller),
                FormWidgets.imageUpload(controller),
                Row(
                  children: [
                    Obx(
                      () => Checkbox(
                        value: controller.isLicensedVisible.value,
                        onChanged: (value) {
                          if (value != null) {
                            controller.toggleLicenseFields(value);
                          }
                        },
                      ),
                    ),
                    const Text(
                      'License & Tax Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

                ///  License Section
                Obx(
                  () => controller.isLicensedVisible.value
                      ? FormWidgets.licenseInfo(controller)
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 15),

                ///  Submit Button
                Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () {
                            if (controller.formKey.currentState!.validate()) {
                              controller.createAccountFromForm(context);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
