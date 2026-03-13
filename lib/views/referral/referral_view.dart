import 'package:arham_corporation/views/referral/referral_controller.dart';
import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReferralView extends StatefulWidget {
  const ReferralView({super.key});

  @override
  State<ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<ReferralView> {
  final ReferralController controller = Get.put(ReferralController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Referral',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.all(AppDimensions.screenPadding),
                  child: Column(
                    children: [
                      const Spacer(),
                      Icon(
                        Icons.card_giftcard_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      CommonText(
                        text: 'Invite Friends & Earn',
                        fontSize: AppDimensions.fontSizeExtraLarge,
                        fontWeight: AppFontWeight.bold,
                      ),
                      const SizedBox(height: 8),
                      CommonText(
                        text: 'Your Referral Code',
                        fontSize: AppDimensions.fontSizeMedium,
                        fontWeight: AppFontWeight.regular,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 12),
                      // App type selector
                      Obx(() => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('App Type: ',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6))),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: controller.selectedAppType.value,
                                items: controller.appTypes
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t.toUpperCase()),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    controller.selectedAppType.value = v;
                                },
                              ),
                            ],
                          )),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.borderRadiusMedium,
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: CommonText(
                            text: controller.referralCode.value.isNotEmpty
                                ? controller.referralCode.value
                                : '---',
                            fontSize: 22,
                            fontWeight: AppFontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Generate button: user triggers generation explicitly
                      CommonButton(
                        buttonText: 'Generate Code',
                        onPressed: () => controller.generateReferralCode(),
                        isLoading: controller.isLoading.value,
                      ),
                      const SizedBox(height: 12),
                      CommonButton(
                        buttonText: 'Copy Code',
                        onPressed: controller.copyReferralCode,
                        isLoading: false,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: controller.shareReferralCode,
                          icon: const Icon(Icons.share),
                          label: CommonText(
                            text: 'Share Referral Link',
                            fontSize: AppDimensions.fontSizeMedium,
                            fontWeight: AppFontWeight.medium,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
