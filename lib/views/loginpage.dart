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
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/views/signuppage.dart';
import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/bottomnavebar.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_input_dialog.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/common_text_button.dart';
import 'package:arham_corporation/widgets/location_disclaimer_dialog.dart';
import 'package:arham_corporation/widgets/location_permission_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../product/controller/product_controller.dart';
import '../providers/item_list_provider.dart';
import '../providers/location_provider.dart';
import '../providers/party_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_permission_service.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;
  bool isLoginProcessing = false; // New state variable to track login process
  bool _hasShownInitialLocationDisclosure = false;
  bool _isShowingInitialLocationDisclosure = false;
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

  Future<void> _checkAndShowLocationPermissionDialog() async {
    try {
      final hasPermission =
          await LocationPermissionService.hasBackgroundLocationPermission();
      if (!hasPermission && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const LocationPermissionDialog(),
        );
      }
    } catch (e) {
      print('[LoginPage] Error checking location permission: $e');
    }
  }

  // Future<void> _showInitialLocationDisclosure() async {
  //   if (_hasShownInitialLocationDisclosure ||
  //       _isShowingInitialLocationDisclosure ||
  //       !mounted) {
  //     return;
  //   }
  //
  //   _isShowingInitialLocationDisclosure = true;
  //
  //   try {
  //     final hasPermission =
  //         await LocationPermissionService.hasBackgroundLocationPermission();
  //
  //     if (!mounted) {
  //       return;
  //     }
  //
  //     if (!hasPermission) {
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (context) => const LocationPermissionDialog(),
  //       );
  //     }
  //   } catch (e) {
  //     print('[LoginPage] Error showing initial location disclosure: $e');
  //   } finally {
  //     _isShowingInitialLocationDisclosure = false;
  //     if (mounted) {
  //       setState(() {
  //         _hasShownInitialLocationDisclosure = true;
  //       });
  //     }
  //   }
  // }
  Future<void> _showInitialLocationDisclosure() async {
    if (_hasShownInitialLocationDisclosure ||
        _isShowingInitialLocationDisclosure ||
        !mounted) {
      return;
    }

    _isShowingInitialLocationDisclosure = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final disclaimerShown =
          prefs.getBool('location_disclaimer_shown') ?? false;

      if (!mounted) return;

      if (!disclaimerShown) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LocationDisclaimerDialog(),
        );

        await prefs.setBool(
          'location_disclaimer_shown',
          true,
        );
      }
    } catch (e) {
      print(
        '[LoginPage] Error showing location disclaimer: $e',
      );
    } finally {
      _isShowingInitialLocationDisclosure = false;

      if (mounted) {
        setState(() {
          _hasShownInitialLocationDisclosure = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    CrashlyticsService.setScreenName('LoginPage');
    CrashlyticsService.logAction('login_screen_opened');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialLocationDisclosure();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasShownInitialLocationDisclosure) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0XFF2c9ed9),
          ),
        ),
      );
    }

    //fToast.init(context); // Initialize FToast
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    final Global global = context.watch<Global>();
    final LocationProvider lc = context.watch<LocationProvider>();
    final UserProvider up = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Image.asset(
            "assets/login_page_bg.png",
            fit: BoxFit.fill,
            height: double.infinity,
            width: double.infinity,
          ),
          SingleChildScrollView(
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
        ],
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
          height: screenHeight * 0.08,
        ),
        Image.asset(
          'assets/arhamOMS_icon.png',
          width: screenWidth * 0.8,
        ),
        SizedBox(
          height: screenHeight * 0.05,
        ),
        Card(
          color: Colors.white,
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
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Color(0xFF1C4FBA)),
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
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Color(0xFF1C4FBA)),
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Expanded(
                      //   child: Obx(
                      //     () => CheckboxListTile(
                      //       contentPadding: EdgeInsets.zero,
                      //       dense: true,
                      //       visualDensity: VisualDensity.compact,
                      //       // checkColor: AppColors.colorWhite,
                      //       // activeColor: AppColors.teal,
                      //       controlAffinity: ListTileControlAffinity.leading,
                      //       // Moves checkbox to right side
                      //       title: InkWell(
                      //         child: RichText(
                      //           text: TextSpan(
                      //             //text: 'Login With Mobile Number',
                      //             text: 'Login through OTP',
                      //             style: GoogleFonts.notoSans(
                      //               fontSize: AppDimensions.fontSizeRegular,
                      //               fontWeight: AppFontWeight.medium,
                      //               color:
                      //                   Theme.of(context).colorScheme.onSurface,
                      //             ),
                      //           ),
                      //         ),
                      //       ),
                      //       value: isLoginWithOTP.value,
                      //       onChanged: (value) {
                      //         setState(() {
                      //           _emailClt.clear();
                      //           _passwordClt.clear();
                      //           mobileNoWithOTPController.value.clear();
                      //           forgotPasswordController.value.clear();
                      //           isLoginProcessing = false;
                      //           isLoginWithOTP.value = value!;
                      //         });
                      //       },
                      //     ),
                      //   ),
                      // ),
                      if (isLoginWithOTP.value == false && tempToken.isEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: CommonTextButton(
                            title: 'Forgot Password?',
                            underline: false,
                            color: Color(0xFF1C4FBA),
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
                // Visibility(
                //   visible: !tempToken.isNotEmpty,
                //   child: SizedBox(
                //     width: 230.0,
                //     child: ElevatedButton(
                //       child: Padding(
                //         padding: const EdgeInsets.all(8.0),
                //         child: global.loadingLogin
                //             ? Center(
                //                 child: SizedBox(
                //                   height: 20.0,
                //                   width: 20.0,
                //                   child: CircularProgressIndicator(
                //                     color: Color(0XFF2c3f9b),
                //                     strokeWidth: 2,
                //                   ),
                //                 ),
                //               )
                //             : Text("Login",
                //                 style: TextStyle(
                //                     fontSize: 18.0, color: Colors.white)),
                //       ),
                //       onPressed: () {
                //         if (isLoginWithOTP.value) {
                //           print('call this 1');
                //           tempLoginValidationWithMobile();
                //         } else {
                //           print('call this 2');
                //           tempLoginValidationWithUserCd(global, lc);
                //         }
                //
                //         //tempLoginValidationWithUserCd(global, lc);
                //       },
                //       style: ButtonStyle(
                //           shape:
                //               WidgetStateProperty.all<RoundedRectangleBorder>(
                //                   RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(10.0),
                //           )),
                //           backgroundColor:
                //               WidgetStateProperty.all(Color(0XFF1269ea))),
                //     ),
                //   ),
                // ),
                Visibility(
                  visible: tempToken.isEmpty,
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3463CD),
                            Color(0xFF1C4FBA),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (isLoginWithOTP.value) {
                            print('call this 1');
                            tempLoginValidationWithMobile();
                          } else {
                            print('call this 2');
                            tempLoginValidationWithUserCd(global, lc);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: global.loadingLogin
                              ? const SizedBox(
                                  height: 20.0,
                                  width: 20.0,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Obx(
                //   () => CheckboxListTile(
                //     contentPadding: EdgeInsets.zero,
                //     dense: true,
                //     visualDensity: VisualDensity.compact,
                //     // checkColor: AppColors.colorWhite,
                //     // activeColor: AppColors.teal,
                //     controlAffinity: ListTileControlAffinity.leading,
                //     // Moves checkbox to right side
                //     title: InkWell(
                //       child: RichText(
                //         text: TextSpan(
                //           //text: 'Login With Mobile Number',
                //           text: 'Login through OTP',
                //           style: GoogleFonts.notoSans(
                //             fontSize: AppDimensions.fontSizeRegular,
                //             fontWeight: AppFontWeight.medium,
                //             color: Theme.of(context).colorScheme.onSurface,
                //           ),
                //         ),
                //       ),
                //     ),
                //     value: isLoginWithOTP.value,
                //     onChanged: (value) {
                //       setState(() {
                //         _emailClt.clear();
                //         _passwordClt.clear();
                //         mobileNoWithOTPController.value.clear();
                //         forgotPasswordController.value.clear();
                //         isLoginProcessing = false;
                //         isLoginWithOTP.value = value!;
                //       });
                //     },
                //   ),
                // ),
                SizedBox(
                  height: 10,
                ),
                Visibility(
                  visible: tempToken.isEmpty,
                  child: Obx(
                    () => InkWell(
                      onTap: () {
                        setState(() {
                          _emailClt.clear();
                          _passwordClt.clear();
                          mobileNoWithOTPController.value.clear();
                          forgotPasswordController.value.clear();
                          isLoginProcessing = false;
                          isLoginWithOTP.value = !isLoginWithOTP.value;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLoginWithOTP.value
                                ? const Color(0xFF1269EA)
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                color: Color(0xFF1269EA),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Login with OTP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isLoginWithOTP.value
                                      ? const Color(0xFF0F172A)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Icon(
                              isLoginWithOTP.value
                                  ? Icons.check_circle
                                  : Icons.arrow_forward_ios_rounded,
                              color: const Color(0xFF1269EA),
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
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
                                      final selectedFirm = firmList.firstWhere(
                                          (firm) => firm['syncId'] == newValue);
                                      selectedFirmName =
                                          selectedFirm['firmName'];

                                      final UserProvider ub =
                                          Provider.of<UserProvider>(context,
                                              listen: false);
                                      ub.saveSyncId(selectedSyncId.toString());
                                      ub.saveSyncName(
                                          selectedFirmName.toString());
                                      // Save CUST_ID when firm is selected
                                      if (selectedFirm['custId'] != null &&
                                          selectedFirm['custId']
                                              .toString()
                                              .isNotEmpty) {
                                        ub.saveCustId(
                                            selectedFirm['custId'].toString());
                                      }
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
                // Visibility(
                //   visible: tempToken.isNotEmpty,
                //   child: SizedBox(
                //     width: double.infinity,
                //     child: ElevatedButton(
                //       child: Padding(
                //         padding: const EdgeInsets.all(8.0),
                //         child: global.loadingfetchLogin
                //             ? Center(
                //                 child: SizedBox(
                //                   height: 20.0,
                //                   width: 20.0,
                //                   child: CircularProgressIndicator(
                //                     color: Color(0XFF2c3f9b),
                //                     strokeWidth: 2,
                //                   ),
                //                 ),
                //               )
                //             : Text("Continue",
                //                 style: TextStyle(
                //                     fontSize: 18.0, color: Colors.white)),
                //       ),
                //       onPressed: () {
                //         changeFirmLoginWithAPI(global, lc);
                //       },
                //       style: ButtonStyle(
                //           shape:
                //               WidgetStateProperty.all<RoundedRectangleBorder>(
                //                   RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(10.0),
                //           )),
                //           backgroundColor:
                //               WidgetStateProperty.all(Color(0XFF2c9ed9))),
                //     ),
                //   ),
                // ),
                Visibility(
                  visible: tempToken.isNotEmpty,
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3463CD),
                            Color(0xFF1C4FBA),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          changeFirmLoginWithAPI(global, lc);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: global.loadingfetchLogin
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (up.showSignUp && tempToken.isEmpty)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 18.0,
                          left: 15.0,
                          right: 15.0,
                        ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Don't Have an account yet?",
                            style: TextStyle(color: Colors.black),
                          ),
                          TextButton(
                            onPressed: (!isLoginProcessing && tempToken.isEmpty)
                                ? () {
                                    Get.to(() => SignUpPage());
                                  }
                                : null,
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                  // Change text color based on button state
                                  color:
                                      (!isLoginProcessing && tempToken.isEmpty)
                                          ? Color(0xFF1C4FBA)
                                          : Colors.grey),
                            ),
                          ),
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
      CrashlyticsService.logAction(
        'login_attempt_started',
        context: {
          'method': 'user_code',
          'user_code': _emailClt.text,
        },
      );

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
                    // Clear ALL auto-cache flags from previous sessions on fresh login
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final keys = prefs.getKeys();
                      for (String key in keys) {
                        if (key.startsWith('auto_cached_firm_')) {
                          await prefs.remove(key);
                          print('[LoginPage] Cleared cached flag: $key');
                        }
                      }
                    } catch (e) {
                      print('[LoginPage] Failed to clear cached flags: $e');
                    }

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
        } else {
          global.loadinglogin(false);
        }
      });
    }
  }

  changeFirmLoginWithAPI(Global global, LocationProvider lc) {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    if (selectedFirmName == null) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please Select Firm');
    } else {
      CrashlyticsService.logAction(
        'firm_change_login_triggered',
        context: {
          'sync_id': selectedSyncId,
          'firm_name': selectedFirmName,
        },
      );
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingfetchlogin(true);
      AuthServices()
          .changeFirmLogin(selectedSyncId.toString(), tempToken, context)
          .then((value) async {
        if (value != null) {
          try {
            await DatabaseHelper().clearOrderTrackingCache();
            print(
                '[LoginPage] Cleared route/order tracking cache (kept punch rows)');
          } catch (e) {
            print('[LoginPage] Failed to clear cache: $e');
          }

          // Save the new syncId FIRST
          final firmSyncId = selectedSyncId.toString();
          await ub.saveSyncId(firmSyncId);
          print('[LoginPage] Saved new syncId: $firmSyncId');

          // Then clear the auto-cache flag for this firm
          try {
            final prefs = await SharedPreferences.getInstance();
            final cacheKey = 'auto_cached_firm_$firmSyncId';
            await prefs.remove(cacheKey);
            await Future.delayed(
                Duration(milliseconds: 100)); // Ensure write completes
            print('[LoginPage] Cleared auto-cache flag for firm $firmSyncId');
          } catch (e) {
            print('[LoginPage] Failed to clear auto-cache flag: $e');
          }

          // Preserve existing role if the response doesn't include one
          final currentRole = ub.role ?? "";
          final newRole = value["role"] ?? currentRole;
          print('[LoginPage] Role preservation: current=$currentRole, API=${{
            value["role"]
          }}, using=$newRole');

          ub.saveUserData(newRole, value["token"]).then((value) {
            ub.setSignIn().then((value) async {
              final locationProvider =
                  Provider.of<LocationProvider>(context, listen: false);
              final userProvider =
                  Provider.of<UserProvider>(context, listen: false);

              if (Get.isRegistered<ProductController>()) {
                final productController = Get.find<ProductController>();
                productController.selectedPartyName.value = '';
                productController.selectedPartyId.value = '';
              }

              // await _checkAndShowLocationPermissionDialog();
              locationProvider.start(userProvider);
              context.read<PartyProvider>().getpartyname(context);
              context.read<ItemListProvider>().getItems(context);
              context.read<ProfileProvider>().getProfile().then((value) async {
                context.read<ProfileProvider>().loadSettings(context);

                // Fetch and cache stockist data on login
                if (Get.isRegistered<ProductController>()) {
                  final productController = Get.find<ProductController>();
                  await productController.fetchStockists(groupCd: '136');
                }

                global.loadinglogin(false);
                global.loadingfetchlogin(false);
                // Ensure product page does not display party name on relogin.
                // Keep ProfileProvider.ACC_NAME/ACC_CD restored so the End Order
                // button appears, but clear controller display values.
                if (Get.isRegistered<ProductController>()) {
                  final productController = Get.find<ProductController>();
                  productController.selectedPartyName.value = '';
                  productController.selectedPartyId.value = '';
                }
                //
                // // Dynamically subscribe if the logging in user matches Master
                // try {
                //   if (newRole.isNotEmpty) {
                //     print(
                //         '[LoginPage] Syncing push alerts channel for role: $newRole');
                //     await NotificationService()
                //         .updateRoleBasedSubscription(newRole, 'M');
                //   }
                // } catch (e) {
                //   print('[LoginPage] Failed setup push role topic link: $e');
                // }

                Get.offAll(() => BottomnavigationBarScreen());
                AppSnackBar.showGetXCustomSnackBar(
                  message: 'Login Success',
                  backgroundColor: Colors.green,
                );
              });
            });
          });
        }
      }).catchError((e, stack) async {
        global.loadingfetchlogin(false);
        global.loadinglogin(false);
        await CrashlyticsService.recordNonFatal(
          e,
          stack ?? StackTrace.current,
          reason: 'firm_change_login_failed',
        );
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Unable to complete login for selected firm',
        );
      });
    }
  }

  //9428411214
  Future<void> _fetchFirmDropdown(String tempToken) async {
    final url =
        Uri.parse(AppConfig.baseURL + 'firm'); // Replace with your API URL

    await CrashlyticsService.logAction('firm_list_api_triggered');

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
              "custId": item['CUST_ID'] ?? '',
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
          // Save CUST_ID if available
          if (firmList.isNotEmpty) {
            final custId = firmList[0]['custId'];
            if (custId != null && custId.isNotEmpty) {
              ub.saveCustId(custId.toString());
            }
          }
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e, stack) {
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'firm_list_fetch_failed',
      );
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
            .then((value) async {
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
            //
            // // Extract role from direct OTP login payload response
            // try {
            //   final String otpUserRole = json.decode(value)["role"] ?? "";
            //   if (otpUserRole.isNotEmpty) {
            //     print(
            //         '[LoginPage-OTP] Dynamic role extraction resolved: $otpUserRole');
            //     await NotificationService()
            //         .updateRoleBasedSubscription(otpUserRole, 'M');
            //   }
            // } catch (e) {
            //   print(
            //       '[LoginPage-OTP] Dynamic role evaluation registration failed: $e');
            // }

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
