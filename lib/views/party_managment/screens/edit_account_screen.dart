import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/edit_account_controller.dart';
import '../widgets/form_widgets.dart';

class EditAccountScreen extends StatefulWidget {
  final Map<String, dynamic> accountData;

  const EditAccountScreen({
    super.key,
    required this.accountData,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late final EditAccountController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<EditAccountController>()
        ? Get.find<EditAccountController>()
        : Get.put(EditAccountController());
    controller.prefill(widget.accountData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Account'),
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: controller.formKey,
            child: Column(
              children: [
                FormWidgets.basicInfo(controller),
                FormWidgets.imageUpload(controller),

                Row(
                  children: [
                    Obx(() => Checkbox(
                          value: controller.isLicensedVisible.value,
                          onChanged: (v) =>
                              controller.toggleLicenseFields(v ?? false),
                        )),
                    const Text('License & Tax Information'),
                  ],
                ),

                Obx(() => controller.isLicensedVisible.value
                    ? FormWidgets.licenseInfo(controller)
                    : const SizedBox()),

                const SizedBox(height: 20),

                /// UPDATE BUTTON
                Obx(
                  () => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () {
                            if (controller.formKey.currentState!.validate()) {
                              controller.updateAccount(context);
                            }
                          },
                    child: controller.isLoading.value
                        ? const CircularProgressIndicator()
                        : const Text('Update Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
