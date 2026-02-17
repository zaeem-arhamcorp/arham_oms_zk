import 'dart:io';

import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class CommonUploadInputDialog extends StatelessWidget {
  final String title;
  final String message;
  final TextEditingController controllerValue;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final RxBool isLoading;

  /// NEW
  final Rx<File?> fileRx;
  final Rxn<Uint8List> webFileRx;
  final VoidCallback onUploadTap;
  final VoidCallback onDeleteTap;

  const CommonUploadInputDialog({
    super.key,
    required this.title,
    required this.message,
    required this.controllerValue,
    required this.onSubmit,
    required this.onCancel,
    required this.isLoading,
    required this.fileRx,
    required this.webFileRx,
    required this.onUploadTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
          () => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(30, 30, 30, 20),
        contentPadding: const EdgeInsets.fromLTRB(30, 0, 30, 30),

        /// TITLE
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommonText(
              text: title,
              fontSize: AppDimensions.fontSizeLarge,
              fontWeight: AppFontWeight.w500,
            ),
            //const SizedBox(height: 8),
            const Divider(thickness: 1),
          ],
        ),

        /// CONTENT
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// MESSAGE
              CommonText(
                text: message,
                fontSize: AppDimensions.fontSizeMedium,
              ),

              const SizedBox(height: 15),

              /// 🔥 TAP TO UPLOAD
              CommonText(
                text: "Upload Image *",
                fontWeight: AppFontWeight.w500,
              ),

              const SizedBox(height: 8),

              Obx(() {
                final file = fileRx.value;
                final webFile = webFileRx.value;

                Widget imageWidget;

                if (kIsWeb && webFile != null) {
                  imageWidget = Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(webFile, fit: BoxFit.contain),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: onDeleteTap,
                        ),
                      ),
                    ],
                  );
                } else if (!kIsWeb && file != null) {
                  imageWidget = Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: onDeleteTap,
                        ),
                      ),
                    ],
                  );
                } else {
                  imageWidget = const Center(
                    child: Text("Tap to upload"),
                  );
                }

                return InkWell(
                  onTap: onUploadTap,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: imageWidget,
                  ),
                );
              }),

              const SizedBox(height: 20),

              /// REMARK FIELD
              CommonAppInput(
                textEditingController: controllerValue,
                hintText: 'Remarks',
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 24),

              /// LOADER OR BUTTONS
              isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                children: [
                  Expanded(
                    child: CommonButton(
                      buttonText: "Submit",
                      onPressed: onSubmit,
                      isLoading: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
