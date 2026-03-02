import 'dart:async';
import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/utlityModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/authservices.dart';
import 'package:arham_corporation/views/signuppage.dart';
import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/bottomnavebar.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_input_dialog.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/common_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../providers/item_list_provider.dart';
import '../providers/location_provider.dart';
import '../providers/party_provider.dart';
import '../providers/user_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;
  bool isLoginProcessing = false; // New state variable to track login process
  TextEditingController _emailClt = TextEditingController();
  TextEditingController _passwordClt = TextEditingController();

  //final FToast fToast = FToast();
  UtlityModal? data;
  String tempToken = '';

  List<Map<String, dynamic>> firmList = [];
  int? selectedSyncId; // Stores the selected sync ID
  String? selectedFirmName; // Stores the selected firm name
  bool isLoading = true; // Indicates loading state

  var isTextFieldDisable = true.obs;

  //var isVerifyCheckLoading = false.obs;
  //var isVerifyCheckDisable = false.obs;
  var isVerifyOTPLoading = false.obs;
  var isVerifyOTPDisable = false.obs;
  var isResendOTPLoading = false.obs;
  var resendSeconds = 60.obs;
  var isResendEnabled = false.obs;
  Timer? _resendTimer;

  //var isResendOTPDisable = false.obs;
  var mobileNo = ''.obs;
  var isVerified = true.obs;
  var verifyOTPController = TextEditingController().obs;
  var mobileNoWithOTPController = TextEditingController().obs;

  //var mobileNoWithOTPFocus = FocusNode();

  var isForgotPassLoading = false.obs;

  //var isForgotPassDisable = false.obs;
  var forgotPasswordController = TextEditingController().obs;

  //var forgotPasswordFocus = FocusNode();

  var isLoginWithOTP = false.obs;

  var isResetPasswordLoading = false.obs;
  var isResetPasswordDisable = false.obs;
  var isResetPasswordEnable = false.obs;
  var newPasswordController = TextEditingController().obs;
  var confirmPasswordController = TextEditingController().obs;

  var newPasswordFocus = FocusNode();
  var confirmPassWordFocus = FocusNode();

  var isNewPasswordObscured = true.obs;
  var isConfirmPasswordObscured = true.obs;

  void newPassToggleObscured() {
    isNewPasswordObscured.value = !isNewPasswordObscured.value;
  }

  void confirmPassToggleObscured() {
    isConfirmPasswordObscured.value = !isConfirmPasswordObscured.value;
  }

  void startResendTimer() {
    resendSeconds.value = 60;
    isResendEnabled.value = false;

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendSeconds.value == 0) {
        timer.cancel();
        isResendEnabled.value = true;
      } else {
        resendSeconds.value--;
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //fToast.init(context); // Initialize FToast
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final Global global = context.watch<Global>();
    final LocationProvider lc = context.watch<LocationProvider>();
    final UserProvider up = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              //child: isVerified.value ? _loginView(context) : _otpView(context),
              child: Obx(() {
                final verified = isVerified.value;
                final resetEnabled = isResetPasswordEnable.value;

                if (verified && resetEnabled)
                  return _resetPasswordView(context);
                if (verified) return _loginView(context);
                return _otpView(context);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginView(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final Global global = context.watch<Global>();
    final LocationProvider lc = context.watch<LocationProvider>();
    final UserProvider up = context.watch<UserProvider>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: screenHeight * 0.1,
        ),
        Image.asset(
          'assets/login_img.png',
          width: screenWidth * 0.3,
        ),
        SizedBox(
          height: screenHeight * 0.05,
        ),
        Card(
          elevation: 8,
          shadowColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16.0), // Optional: Shape customization
          ),
          child: Container(
            width: screenWidth * 0.9,
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 15.0, top: 20.0),
                        child: Text('Login',
                            style: TextStyle(
                                fontSize: 30.0, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (!isLoginWithOTP.value)
                      TextField(
                        textInputAction: TextInputAction.next,
                        controller: _emailClt,
                        enabled: !isLoginProcessing && tempToken.isEmpty,
                        // Disable during login
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          labelText: 'User Code',
                          prefixIcon:
                              Icon(Icons.email_outlined, color: Colors.black),
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0XFF2c9ed9), width: 2.0),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          counterText: '',
                          enabled: !isLoginProcessing &&
                              tempToken.isEmpty, // Apply disabled state styling
                        ),
                      ),
                    if (!isLoginWithOTP.value)
                      SizedBox(
                        height: 10,
                      ),
                    if (!isLoginWithOTP.value)
                      TextField(
                        textInputAction: TextInputAction.done,
                        controller: _passwordClt,
                        enabled: !isLoginProcessing && tempToken.isEmpty,
                        // Disable during login
                        obscureText: !showPassword,
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                              Icon(Icons.lock_outline, color: Colors.black),
                          suffixIcon: GestureDetector(
                            onTap: !isLoginProcessing
                                ? () {
                                    setState(() {
                                      showPassword = !showPassword;
                                    });
                                  }
                                : null,
                            child: showPassword
                                ? Icon(Icons.remove_red_eye_outlined,
                                    color: Colors.black)
                                : Icon(Icons.visibility_off_outlined,
                                    color: Colors.black),
                          ),
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0XFF2c9ed9), width: 2.0),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          enabled: !isLoginProcessing &&
                              tempToken.isEmpty, // Apply disabled state styling
                        ),
                      ),
                    if (isLoginWithOTP.value)
                      TextField(
                        controller: mobileNoWithOTPController.value,
                        enabled: !isLoginProcessing && tempToken.isEmpty,
                        // Disable during login
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        cursorColor: Colors.black,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number *',
                          prefixIcon: Icon(Icons.phone_android_outlined,
                              color: Colors.black),
                          labelStyle: TextStyle(color: Colors.black),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0XFF2c9ed9), width: 2.0),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          counterText: '',
                          enabled: !isLoginProcessing &&
                              tempToken.isEmpty, // Apply disabled state styling
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.done,
                      ),
                  ],
                ),
                if (tempToken.isEmpty)
                  Row(
                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Obx(
                          () => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            // checkColor: AppColors.colorWhite,
                            // activeColor: AppColors.teal,
                            controlAffinity: ListTileControlAffinity.leading,
                            // Moves checkbox to right side
                            title: InkWell(
                              child: RichText(
                                text: TextSpan(
                                  //text: 'Login With Mobile Number',
                                  text: 'Login through OTP',
                                  style: GoogleFonts.notoSans(
                                    fontSize: AppDimensions.fontSizeRegular,
                                    fontWeight: AppFontWeight.medium,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            value: isLoginWithOTP.value,
                            onChanged: (value) {
                              setState(() {
                                _emailClt.clear();
                                _passwordClt.clear();
                                mobileNoWithOTPController.value.clear();
                                forgotPasswordController.value.clear();
                                isLoginProcessing = false;
                                isLoginWithOTP.value = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      if (isLoginWithOTP.value == false && tempToken.isEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: CommonTextButton(
                            title: 'Forgot Password?',
                            underline: false,
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => CommonInputDialog(
                                  title: 'Forgot Password',
                                  message:
                                      'Enter your mobile number to forgot your password.',
                                  controllerValue:
                                      forgotPasswordController.value,
                                  isLoading: isForgotPassLoading,
                                  onSubmit: () {
                                    forgotPasswordWithAPI();
                                  },
                                  onCancel: () {
                                    forgotPasswordController.value.clear();

                                    Get.back();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ).paddingOnly(top: 8, bottom: 8),
                Visibility(
                  visible: !tempToken.isNotEmpty,
                  child: SizedBox(
                    width: 230.0,
                    child: ElevatedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: global.loadingLogin
                            ? Center(
                                child: SizedBox(
                                  height: 20.0,
                                  width: 20.0,
                                  child: CircularProgressIndicator(
                                    color: Color(0XFF2c3f9b),
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Text("Login",
                                style: TextStyle(
                                    fontSize: 18.0, color: Colors.white)),
                      ),
                      onPressed: () {
                        if (isLoginWithOTP.value) {
                          print('call this 1');
                          tempLoginValidationWithMobile();
                        } else {
                          print('call this 2');
                          tempLoginValidationWithUserCd(global, lc);
                        }

                        //tempLoginValidationWithUserCd(global, lc);
                      },
                      style: ButtonStyle(
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          )),
                          backgroundColor:
                              WidgetStateProperty.all(Color(0XFF2c9ed9))),
                    ),
                  ),
                ),
                if (tempToken.isNotEmpty)
                  SizedBox(
                    height: 10,
                  ),
                if (tempToken.isNotEmpty)
                  isLoading
                      ? CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.0,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  iconEnabledColor: Colors.black,
                                  decoration: InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12.0),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                          color: Colors.black, width: 1.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                          color: Colors.black, width: 1.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                          color: Colors.black, width: 1.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      borderSide: BorderSide(
                                          color: Colors.black, width: 1.0),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  hint: Text(
                                    "Select Firm",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  initialValue: selectedSyncId,
                                  items: firmList.map((firm) {
                                    return DropdownMenuItem<int>(
                                      value: firm['syncId'],
                                      child: Text(firm['firmName']),
                                    );
                                  }).toList(),
                                  onChanged: (int? newValue) {
                                    setState(() {
                                      selectedSyncId = newValue;
                                      selectedFirmName = firmList.firstWhere(
                                          (firm) =>
                                              firm['syncId'] ==
                                              newValue)['firmName'];

                                      final UserProvider ub =
                                          Provider.of<UserProvider>(context,
                                              listen: false);
                                      ub.saveSyncId(selectedSyncId.toString());
                                      ub.saveSyncName(
                                          selectedFirmName.toString());
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                SizedBox(
                  height: 10,
                ),
                Visibility(
                  visible: tempToken.isNotEmpty,
                  child: SizedBox(
                    width: 230.0,
                    child: ElevatedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: global.loadingfetchLogin
                            ? Center(
                                child: SizedBox(
                                  height: 20.0,
                                  width: 20.0,
                                  child: CircularProgressIndicator(
                                    color: Color(0XFF2c3f9b),
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Text("Continue",
                                style: TextStyle(
                                    fontSize: 18.0, color: Colors.white)),
                      ),
                      onPressed: () {
                        changeFirmLoginWithAPI(global, lc);
                      },
                      style: ButtonStyle(
                          shape:
                              WidgetStateProperty.all<RoundedRectangleBorder>(
                                  RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          )),
                          backgroundColor:
                              WidgetStateProperty.all(Color(0XFF2c9ed9))),
                    ),
                  ),
                ),
                if (up.showSignUp)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 18.0, left: 15.0, right: 15.0),
                        child: Row(children: <Widget>[
                          Expanded(
                              child: Divider(
                            color: Colors.black,
                            thickness: 0.8,
                          )),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              "OR",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                            color: Colors.black,
                            thickness: 0.8,
                          )),
                        ]),
                      ),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: Text(
                              "Don't Have an account yet?",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          TextButton(
                              onPressed:
                                  (!isLoginProcessing && tempToken.isEmpty)
                                      ? () {
                                          Get.to(() => SignUpPage());
                                        }
                                      : null,
                              child: Text(
                                "Sign Up",
                                style: TextStyle(
                                    // Change text color based on button state
                                    color: (!isLoginProcessing &&
                                            tempToken.isEmpty)
                                        ? Color(0XFF2c9ed9)
                                        : Colors.grey),
                              ))
                        ],
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpView(BuildContext context) {
    startResendTimer(); // restart timer

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;

    final defaultPinTheme = PinTheme(
      width: 45,
      height: 45,
      textStyle: TextStyle(
        fontSize: 20,
        color: primary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(4),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: primary, width: 2),
      borderRadius: BorderRadius.circular(4),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(color: surface),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      //mainAxisSize: MainAxisSize.min,
      children: [
        CommonText(
          text: 'Verification',
          fontSize: AppDimensions.fontSizeExtraLarge,
          fontWeight: AppFontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
        ),
        CommonText(
          text: "Enter the code sent to the number",
          fontSize: AppDimensions.fontSizeMedium,
          fontWeight: AppFontWeight.w600,
        ).paddingOnly(top: 25),
        if (mobileNo.value.isNotEmpty)
          Obx(
            () => CommonText(
              //text: mobileNo.value,
              text: Helper.maskMobileNumber(mobileNo.value),
              fontSize: AppDimensions.fontSizeMedium,
              fontWeight: AppFontWeight.w900,
            ).paddingOnly(top: 20),
          ),
        Pinput(
          length: 6,
          autofocus: true,
          showCursor: true,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: submittedPinTheme,
          // 🚫 Disable all autofill
          autofillHints: const [],
          //androidSmsAutofillMethod: AndroidSmsAutofillMethod.none,
          keyboardType: TextInputType.number,
          defaultPinTheme: defaultPinTheme,
          onCompleted: (pin) {
            debugPrint('OTP entered: $pin');
            verifyOTPController.value.text = pin.toString();

            verifyOTPValidation();
          },
          // validator: (s) {
          //   return controller.verifyOTPController.value.text = s.toString();
          // },
          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
        ).paddingOnly(top: 35),
        CommonText(
          text: "Didn't receive the code?",
          fontSize: AppDimensions.fontSizeMedium,
          fontWeight: AppFontWeight.w600,
        ).paddingOnly(top: 30),
        // isResendOTPLoading.value
        //     ? SizedBox(
        //         height: 25,
        //         child: Center(child: CircularProgressIndicator()),
        //       )
        //     : CommonTextButton(
        //         title: 'Resend',
        //         underline: true,
        //         onPressed: () {
        //           resendOTPValidation();
        //         },
        //       ).paddingOnly(top: 10),
        Obx(() {
          if (isResendOTPLoading.value) {
            return const SizedBox(
              height: 25,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!isResendEnabled.value) {
            return CommonText(
              text: 'Resend in ${resendSeconds.value}s',
              fontSize: 14,
            ).paddingOnly(top: 10);
          }

          return CommonTextButton(
            title: 'Resend',
            underline: true,
            onPressed: () {
              resendOTPValidation();
              startResendTimer(); // restart timer
            },
          ).paddingOnly(top: 10);
        }),
        Obx(
          () => CommonButton(
            buttonText: 'Verify OTP',
            onPressed: () {
              verifyOTPValidation();
            },
            isLoading: isVerifyOTPLoading.value,
            isDisable: isVerifyOTPDisable.value,
          ),
        ).paddingOnly(top: 16),
      ],
    );
  }

  // void showAnimatedToast() {
  //   Widget toast = StatefulBuilder(
  //     builder: (context, setState) {
  //       return TweenAnimationBuilder(
  //         tween: Tween<double>(begin: 0, end: 10), // Animation range
  //         duration: Duration(seconds: 2), // Animation duration
  //         builder: (context, value, child) {
  //           return Transform.translate(
  //             offset: Offset(0, value),
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
  //               decoration: BoxDecoration(
  //                 color: Colors.red,
  //                 borderRadius: BorderRadius.circular(5.0), // Rectangular shape
  //               ),
  //               child: Text(
  //                 "Please Enter Mobile No.",
  //                 style: TextStyle(color: Colors.white, fontSize: 16.0),
  //                 textAlign: TextAlign.end,
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  //
  //   fToast.showToast(
  //     child: toast,
  //     toastDuration: Duration(seconds: 5),
  //   );
  // }
  void showAnimatedps() {
    // Widget toast = StatefulBuilder(
    //   builder: (context, setState) {
    //     return TweenAnimationBuilder(
    //       tween: Tween<double>(begin: 0, end: 10), // Animation range
    //       duration: Duration(seconds: 2), // Animation duration
    //       builder: (context, value, child) {
    //         return Transform.translate(
    //           offset: Offset(0, value),
    //           child: Container(
    //             padding: const EdgeInsets.symmetric(
    //                 horizontal: 20.0, vertical: 12.0),
    //             decoration: BoxDecoration(
    //               color: Colors.red,
    //               borderRadius: BorderRadius.circular(5.0), // Rectangular shape
    //             ),
    //             child: Text(
    //               "Please Enter Password . ",
    //               style: TextStyle(color: Colors.white, fontSize: 16.0),
    //               textAlign: TextAlign.end,
    //             ),
    //           ),
    //         );
    //       },
    //     );
    //   },
    // );

    // fToast.showToast(
    //   child: toast,
    //   toastDuration: Duration(seconds: 3),
    // );
  }

  tempLoginValidationWithUserCd(Global global, LocationProvider lc) {
    if (_emailClt.text.isEmpty) {
      // FocusScope.of(context).unfocus();
      // showAnimatedToast(message: 'Please Enter UserCode ', color: Colors.red);

      AppSnackBar.showGetXCustomSnackBar(message: 'Please Enter UserCode');
      return true;
    } else if (_passwordClt.text.isEmpty) {
      // FocusScope.of(context).unfocus();
      // showAnimatedToast(message: 'Please Enter Password', color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: 'Please Enter Password');
      return true;
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadinglogin(true);

      //TODO : OLD LOGIN API CALL
      // Authservices()
      //     .performLoginWithUserCd(_emailClt.text, _passwordClt.text, context)
      //     .then((value) async {
      //   if (value != null) {
      //     setState(() {
      //       tempToken = json.decode(value)["tempToken"];
      //     });
      //
      //     if (tempToken.isNotEmpty) {
      //       _fetchFirmDropdown(tempToken);
      //     } else {}
      //   }
      // });

      //TODO : NEW LOGIN API CALL
      AuthServices()
          .checkVerifiedWithCodeOTP(_emailClt.text, context)
          .then((response) async {
        if (response != null) {
          if (response['status'] == true) {
            global.loadinglogin(false);

            isLoginProcessing = false;
            mobileNo.value = response['data']['MOBILENO'];
            isVerified.value = response['data']['IS_VERIFIED'];

            if (isVerified.value == true) {
              AuthServices()
                  .performLoginWithUserCd(
                      _emailClt.text, _passwordClt.text, context)
                  .then((value) async {
                if (value != null) {
                  setState(() {
                    tempToken = json.decode(value)["tempToken"];
                  });

                  if (tempToken.isNotEmpty) {
                    _fetchFirmDropdown(tempToken);
                  } else {}
                }
              });
            } else {
              print('open otp fields');
              // show OTP UI here
            }
          } else {
            AppSnackBar.showGetXCustomSnackBar(
              message: response['message'] ?? "Verification failed",
            );
          }
        }
      });
    }
  }

  changeFirmLoginWithAPI(Global global, LocationProvider lc) {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    if (selectedFirmName == null) {
      //Fluttertoast.showToast(msg: "Please Select Firm");
      AppSnackBar.showGetXCustomSnackBar(message: 'Please Select Firm');
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingfetchlogin(true);
      AuthServices()
          .changeFirmLogin(selectedSyncId.toString(), tempToken, context)
          .then((value) {
        if (value != null) {
          ub.saveUserData(value["role"] ?? "", value["token"]).then((value) {
            ub.setSignIn().then((value) {
              final locationProvider =
                  Provider.of<LocationProvider>(context, listen: false);
              final userProvider =
                  Provider.of<UserProvider>(context, listen: false);
              locationProvider.start(userProvider);
              //context.read<LocationProvider>().start(context);
              context.read<PartyProvider>().getpartyname(context);
              context.read<ItemListProvider>().getItems(context);
              context.read<ProfileProvider>().getProfile(context).then((value) {
                global.loadinglogin(false);
                global.loadingfetchlogin(false);

                Get.offAll(() => BottomnavigationBarScreen());
                // Fluttertoast.showToast(msg: "Login Success");
                // showAnimatedToast(
                //     message: 'Login Success', color: Colors.green);
                AppSnackBar.showGetXCustomSnackBar(
                    message: 'Login Success', backgroundColor: Colors.green);
              });
            });
          });
        }
      });
    }
  }

  //9428411214
  Future<void> _fetchFirmDropdown(String tempToken) async {
    final url =
        Uri.parse(AppConfig.baseURL + 'firm'); // Replace with your API URL

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${tempToken}",
          'x-app-type': 'oms',
        },
      );

      print(url);
      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          firmList = firms.map((item) {
            return {
              "firmName":
                  item['FIRM_NAME']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                      'Unnamed Firm',
              "syncId": item['SYNC_ID'],
            };
          }).toList();

          // Set default firm selection if list is not empty
          if (firmList.isNotEmpty) {
            selectedSyncId = firmList[0]['syncId'];
            selectedFirmName = firmList[0]['firmName'];
          }

          isLoading = false;
        });

        // Save default values to UserProvider
        if (selectedSyncId != null && selectedFirmName != null) {
          final UserProvider ub =
              Provider.of<UserProvider>(context, listen: false);
          ub.saveSyncId(selectedSyncId.toString());
          ub.saveSyncName(selectedFirmName.toString());
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void tempLoginValidationWithMobile() async {
    if (mobileNoWithOTPController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter mobile number.',
      );
    } else if (mobileNoWithOTPController.value.text.isNotEmpty &&
        mobileNoWithOTPController.value.text.length != 10) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter a valid mobile number.',
      );
    } else {
      // Authservices()
      //     .checkVerifiedWithCodeOTP(
      //         mobileNoWithOTPController.value.text, context)
      //     .then((value) {
      //   if (value != null) {
      //     isTextFieldDisable.value = false;
      //     mobileNo.value = value['data']['MOBILENO'];
      //     isVerified.value = value['data']['IS_VERIFIED'];
      //
      //     if (isVerified.value == true) {
      //       FocusManager.instance.primaryFocus?.unfocus();
      //       global.loadinglogin(true);
      //       Authservices()
      //           .performLoginWithUserCd(
      //               _emailClt.text, _passwordClt.text, context)
      //           .then((value) async {
      //         if (value != null) {
      //           setState(() {
      //             tempToken = json.decode(value)["tempToken"];
      //           });
      //
      //           if (tempToken.isNotEmpty) {
      //             _fetchFirmDropdown(tempToken);
      //           } else {}
      //         }
      //       });
      //     } else {
      //       print('open otp fields');
      //       // AppSnackBar.showGetXCustomSnackBar(
      //       //   message: "OTP Not Verified",
      //       //   backgroundColor: Colors.red,
      //       // );
      //     }
      //   }
      // });

      final Global global = Provider.of<Global>(context, listen: false);
      global.loadingsignup(true);

      await AuthServices()
          .performLoginWithMobile(mobileNoWithOTPController.value.text, context)
          .then((value) {
        if (value != null) {
          FocusManager.instance.primaryFocus?.unfocus();
          global.loadingsignup(false);

          mobileNo.value = mobileNoWithOTPController.value.text;
          isVerified.value = false;

          AppSnackBar.showGetXCustomSnackBar(
              message:
                  'OTP has been sent successfully to your mobile number ${mobileNoWithOTPController.value.text}',
              backgroundColor: Colors.green);
        }
      });
    }
  }

  void verifyOTPValidation() {
    final Global global = Provider.of<Global>(context, listen: false);
    global.loadinglogin(true);

    if (verifyOTPController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter OTP.');
    } else if (verifyOTPController.value.text.isNotEmpty &&
        verifyOTPController.value.text.length < 6) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter a valid OTP.');
    } else {
      if (isLoginWithOTP.value) {
        mobileNoWithOTPController.value.text = mobileNo.value;

        AuthServices()
            .performLoginWithMobileOTP(
                mobileNo.value, verifyOTPController.value.text, context)
            .then((value) {
          if (value != null) {
            FocusManager.instance.primaryFocus?.unfocus();
            global.loadingsignup(false);

            isVerified.value = true;
            isTextFieldDisable.value = true;
            isLoginProcessing = false;

            setState(() {
              //tempToken = json.decode(value)["tempToken"];
              tempToken = json.decode(value)["token"];
            });

            if (tempToken.isNotEmpty) {
              _fetchFirmDropdown(tempToken);
            } else {}
          }
        });
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
        //global.loadingsignup(true);

        AuthServices()
            .verifyOTP(
          mobileNo.value,
          verifyOTPController.value.text,
          context,
        )
            .then((value) {
          if (value != null) {
            global.loadingsignup(false);

            //Navigator.pop(context);
            if (isResetPasswordEnable.value) {
              AppSnackBar.showGetXCustomSnackBar(
                message: 'Verify OTP successfully',
                backgroundColor: Colors.green,
              );

              //isResetPasswordEnable.value = true;
              isVerified.value = true;
              isTextFieldDisable.value = false;
              isLoginProcessing = false;
            } else {
              AppSnackBar.showGetXCustomSnackBar(
                message: 'Verify OTP successfully',
                backgroundColor: Colors.green,
              );

              isVerified.value = true;
              isTextFieldDisable.value = false;
              isLoginProcessing = false;

              FocusManager.instance.primaryFocus?.unfocus();
              global.loadinglogin(true);
              AuthServices()
                  .performLoginWithUserCd(
                      _emailClt.text, _passwordClt.text, context)
                  .then((value) async {
                if (value != null) {
                  setState(() {
                    tempToken = json.decode(value)["tempToken"];
                  });

                  if (tempToken.isNotEmpty) {
                    _fetchFirmDropdown(tempToken);
                  } else {}
                }
              });
            }
          } else {
            global.loadingsignup(false);
          }
        });
      }
    }
  }

  void resendOTPValidation() {
    final Global global = Provider.of<Global>(context, listen: false);
    FocusManager.instance.primaryFocus?.unfocus();
    global.loadingsignup(true);

    AuthServices().resendOTP(mobileNo.value, context).then((value) {
      if (value != null) {
        global.loadingsignup(false);

        verifyOTPController.value.clear();

        AppSnackBar.showGetXCustomSnackBar(
          message: 'OTP resent successfully',
          backgroundColor: Colors.green,
        );
      } else {
        global.loadingsignup(false);
      }
    });
  }

  void forgotPasswordWithAPI() {
    final Global global = Provider.of<Global>(context, listen: false);

    if (forgotPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter mobile number.',
      );
    } else if (forgotPasswordController.value.text.isNotEmpty &&
        forgotPasswordController.value.text.length != 10) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter a valid mobile number.',
      );
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingsignup(true);

      AuthServices()
          .forgotPassword(forgotPasswordController.value.text, context)
          .then((value) {
        if (value != null) {
          global.loadingsignup(false);

          mobileNo.value = forgotPasswordController.value.text;
          forgotPasswordController.value.clear();

          AppSnackBar.showGetXCustomSnackBar(
            message: 'Forgot password send successfully',
            backgroundColor: Colors.green,
          );

          Navigator.of(context).pop();

          // Authservices()
          //     .checkVerifiedMobileOTP(mobileNo.value, context)
          //     .then((value) {
          //   if (value != null) {
          //     //isVerified.value = value['data']['IS_VERIFIED'];
          //
          //     if (value['status'] == true) {
          //       mobileNo.value = value['data']['MOBILENO'];
          //       isVerified.value = value['data']['IS_VERIFIED'];
          //       print('Mobile No Verified ${isVerified.value}');
          //       FocusManager.instance.primaryFocus?.unfocus();
          //
          //       if (isVerified.value == true) {
          //         Authservices()
          //             .performLoginWithUserCd(
          //                 _emailClt.text, _passwordClt.text, context)
          //             .then((value) async {
          //           if (value != null) {
          //             setState(() {
          //               tempToken = json.decode(value)["tempToken"];
          //             });
          //
          //             if (tempToken.isNotEmpty) {
          //               _fetchFirmDropdown(tempToken);
          //             } else {}
          //           }
          //         });
          //
          //         // if(isLoginWithOTP.value){
          //         //   _performLoginWithMobile(mobileNo.value);
          //         // }else {
          //         //   _performLoginWithUserCd(
          //         //     clientCdController.value.text,
          //         //     passwordController.value.text,
          //         //   );
          //         // }
          //       } else {
          //         print('open otp fields');
          //
          //         // AppSnackBar.showGetXCustomSnackBar(
          //         //   message: "OTP Not Verified",
          //         //   backgroundColor: Colors.red,
          //         // );
          //       }
          //     }
          //   }
          // });

          AuthServices()
              .checkVerifiedMobileOTP(mobileNo.value, context)
              .then((response) async {
            if (response != null) {
              if (response['status'] == true) {
                FocusManager.instance.primaryFocus?.unfocus();
                global.loadinglogin(false);

                isLoginProcessing = false;
                mobileNo.value = response['data']['MOBILENO'];
                isVerified.value = response['data']['IS_VERIFIED'];
                isResetPasswordEnable.value = true;
                print('Mobile No Verified ${isVerified.value}');

                if (isVerified.value == true) {
                  AuthServices()
                      .performLoginWithUserCd(
                          _emailClt.text, _passwordClt.text, context)
                      .then((value) async {
                    if (value != null) {
                      setState(() {
                        tempToken = json.decode(value)["tempToken"];
                      });

                      if (tempToken.isNotEmpty) {
                        _fetchFirmDropdown(tempToken);
                      } else {}
                    }
                  });

                  // if(isLoginWithOTP.value){
                  //   _performLoginWithMobile(mobileNo.value);
                  // }else {
                  //   _performLoginWithUserCd(
                  //     clientCdController.value.text,
                  //     passwordController.value.text,
                  //   );
                  // }
                } else {
                  global.loadinglogin(false);
                  print('open otp fields');

                  // AppSnackBar.showGetXCustomSnackBar(
                  //   message: "OTP Not Verified",
                  //   backgroundColor: Colors.red,
                  // );
                }
              } else {
                AppSnackBar.showGetXCustomSnackBar(
                  message: response['message'] ?? "Verification failed",
                );
              }
            }
          });
        }
      });
    }
  }

  void resetPasswordWithAPI() {
    final Global global = Provider.of<Global>(context, listen: false);

    if (newPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter new password.',
      );
    } else if (confirmPasswordController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
        message: 'Please enter confirm password.',
      );
    } else if (confirmPasswordController.value.text !=
        newPasswordController.value.text) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Confirm Password & New Password Not Match.');
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadinglogin(true);

      AuthServices()
          .resetPassword(
        mobileNo.value,
        verifyOTPController.value.text,
        newPasswordController.value.text,
        context,
      )
          .then((value) {
        if (value != null) {
          global.loadinglogin(false);

          AppSnackBar.showGetXCustomSnackBar(
            message: 'Reset password successfully',
            backgroundColor: Colors.green,
          );

          mobileNo.value = '';
          isResetPasswordEnable.value = false;
          isLoginProcessing = false;
          isVerified.value = true;
          isTextFieldDisable.value = false;
        } else {
          global.loadinglogin(false);
        }
      });
    }
  }

  Widget _resetPasswordView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      //mainAxisSize: MainAxisSize.min,
      children: [
        CommonText(
          text: 'Reset Password',
          fontSize: AppDimensions.fontSizeExtraLarge,
          fontWeight: AppFontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
        ),
        if (mobileNo.value.isNotEmpty)
          Obx(
            () => CommonText(
              //text: mobileNo.value,
              text:
                  "OTP verified for ${Helper.maskMobileNumber(mobileNo.value)}.Enter your new password below.",
              fontSize: AppDimensions.fontSizeMedium,
              fontWeight: AppFontWeight.w900,
            ).paddingOnly(top: 25),
          ),
        SizedBox(
          height: 20,
        ),
        CommonAppInput(
          maxLines: 1,
          suffixIcon: isNewPasswordObscured.value
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          onSubmitted: (val) {
            FocusScope.of(context).requestFocus(confirmPassWordFocus);
          },
          onSuffixClick: () => newPassToggleObscured(),
          textInputAction: TextInputAction.next,
          textEditingController: newPasswordController.value,
          hintText: "Password",
          maxLength: 12,
          focusNode: newPasswordFocus,
          isPassword: isNewPasswordObscured.value ? true : false,
          nextFocusNode: confirmPassWordFocus,
        ),
        SizedBox(
          height: 10,
        ),
        CommonAppInput(
          maxLines: 1,
          textInputAction: TextInputAction.done,
          suffixIcon: isConfirmPasswordObscured.value
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          maxLength: 12,
          onSuffixClick: () => confirmPassToggleObscured(),
          textEditingController: confirmPasswordController.value,
          hintText: "Confirm Password",
          focusNode: confirmPassWordFocus,
          isPassword: isConfirmPasswordObscured.value ? true : false,
        ),
        Obx(
          () => CommonButton(
            buttonText: 'Reset Password',
            onPressed: () {
              resetPasswordWithAPI();
            },
            isLoading: isResetPasswordLoading.value,
            isDisable: isResetPasswordDisable.value,
          ),
        ).paddingOnly(top: 16),
      ],
    );
  }
}
