import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class CommonInputDialog extends StatelessWidget {
  final String title;
  final String message;
  final TextEditingController controllerValue;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final RxBool isLoading;

  const CommonInputDialog({
    super.key,
    required this.title,
    required this.message,
    required this.controllerValue,
    required this.onSubmit,
    required this.onCancel,
    required this.isLoading,
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

        /// Title
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CommonText(
              text: title,
              fontSize: AppDimensions.fontSizeLarge,
              fontWeight: AppFontWeight.w500,
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 1),
          ],
        ),

        /// Content
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message Text
            CommonText(
              textAlign: TextAlign.start,
              text: message,
              fontSize: AppDimensions.fontSizeMedium,
              fontWeight: AppFontWeight.w400,
            ),
            const SizedBox(height: 10),
            CommonAppInput(
              textEditingController:
              controllerValue,
              hintText: 'Mobile Number *',
              maxLength: 10,
              textInputAction: TextInputAction.done,
              textInputType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),

            // /// Email Field
            // TextFormField(
            //   controller: emailController,
            //   keyboardType: TextInputType.emailAddress,
            //   decoration: InputDecoration(
            //     labelText: "Email Address",
            //     border: OutlineInputBorder(
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //   ),
            // ),

            const SizedBox(height: 24),

            /// Loader or Buttons
            isLoading.value
                ? Center(child: CircularProgressIndicator())
                : Row(
              children: [
                /// Submit Button
                Expanded(
                  child: CommonButton(
                    buttonText: "Submit",
                    onPressed: onSubmit,
                    isLoading: false,
                  ),
                ),

                const SizedBox(width: 16),

                /// Cancel Button (No BG, Red Border)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: CommonText(
                      text: "Cancel",
                      fontSize: AppDimensions.fontSizeMedium,
                      fontWeight: AppFontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
