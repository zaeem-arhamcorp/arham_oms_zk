import 'dart:async';
import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/user_exits_response.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/widgets/app_dimensions.dart';
import 'package:arham_corporation/widgets/app_font_weight.dart';
import 'package:arham_corporation/widgets/common_button.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:arham_corporation/widgets/common_text_button.dart';
import 'package:cancellation_token_http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/services/authservices.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../providers/global.dart';

class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool showPassword = false;
  TextEditingController _userCd = TextEditingController();
  TextEditingController _password = TextEditingController();
  TextEditingController _username = TextEditingController();
  TextEditingController _mobile = TextEditingController();
  TextEditingController _firmName = TextEditingController();
  TextEditingController _emailID = TextEditingController();

  //final FToast fToast = FToast();

  FocusNode _userCdFocusNode = FocusNode();
  FocusNode _passwordFocusNode = FocusNode();
  FocusNode _usernameFocusNode = FocusNode();
  FocusNode _mobileFocusNode = FocusNode();
  FocusNode _firmNameFocusNode = FocusNode();
  FocusNode _emailIDFocusNode = FocusNode();

  var isUserExitsLoading = false.obs;
  var userErrorMsg = ''.obs;
  Timer? _debounce;

  var isVerifyCheckLoading = false.obs;
  var isVerifyCheckDisable = false.obs;
  var isVerifyOTPLoading = false.obs;
  var isVerifyOTPDisable = false.obs;
  var isResendOTPLoading = false.obs;
  var isResendOTPDisable = false.obs;
  var mobileNo = ''.obs;
  var isVerified = true.obs;
  var verifyOTPController = TextEditingController().obs;
  var resendSeconds = 60.obs;
  var isResendEnabled = false.obs;
  Timer? _resendTimer;

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
    _userCdFocusNode.dispose();
    _passwordFocusNode.dispose();
    _usernameFocusNode.dispose();
    _mobileFocusNode.dispose();
    _firmNameFocusNode.dispose();
    _emailIDFocusNode.dispose();
    verifyOTPController.value.dispose();
    verifyOTPController.close();
    _resendTimer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    // fToast.init(context); // Initialize FToast
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 50.h),
            child: isVerified.value ? _signUpView(context) : _otpView(context),
          ),
        ),
      ),
    );
  }

  Widget _signUpView(BuildContext context) {
    final Global global = context.watch<Global>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/login_img.png', width: 150.w),
        SizedBox(height: 20.h),
        Card(
          elevation: 5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('Sign Up',
                      style: TextStyle(
                          fontSize: 30.sp, fontWeight: FontWeight.w500)),
                ),
                SizedBox(height: 20.h),
                _buildTextField(
                    _userCd,
                    'User  Code',
                    Icons.account_circle_outlined,
                    _userCdFocusNode,
                    _passwordFocusNode,
                    false,
                    onChanged: onClientCdChanged,
                    10),
                Obx(() {
                  return userErrorMsg.value.isNotEmpty
                      ? CommonText(text: userErrorMsg.value, color: Colors.red)
                          .paddingOnly(top: 10)
                      : const SizedBox.shrink();
                }),
                _buildTextField(_password, 'Password', Icons.lock_outline,
                    _passwordFocusNode, _usernameFocusNode, true, 10),
                _buildTextField(_username, 'Name', Icons.person,
                    _usernameFocusNode, _mobileFocusNode, false, 40),
                _buildTextField(_mobile, 'Mobile No.', Icons.phone,
                    _mobileFocusNode, _firmNameFocusNode, false, 10,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ]),
                _buildTextField(_firmName, 'Firm Name', Icons.business,
                    _firmNameFocusNode, _emailIDFocusNode, false, 40),
                _buildEmailField(),
                SizedBox(height: 20.h),
                _buildSignUpButton(global),
                _buildLoginPrompt(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    FocusNode currentFocus,
    FocusNode nextFocus,
    bool isPassword,
    int maxLength, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged, // 👈 dynamic onChanged
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: TextField(
        controller: controller,
        focusNode: currentFocus,
        obscureText: isPassword && !showPassword,
        cursorColor: Colors.black,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters ?? [],
        onChanged: onChanged,
        // 👈 attach here
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.black),
          labelStyle: TextStyle(color: Colors.black),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF2c9ed9), width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          counterText: '',
        ),
        onSubmitted: (_) {
          FocusScope.of(context).requestFocus(nextFocus);
        },
      ),
    );
  }

  Widget _buildEmailField() {
    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: TextField(
        controller: _emailID,
        focusNode: _emailIDFocusNode,
        cursorColor: Colors.black,
        keyboardType: TextInputType.emailAddress,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: 'Email Id',
          prefixIcon: Icon(Icons.email_outlined, color: Colors.black),
          labelStyle: TextStyle(color: Colors.black),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF2c9ed9), width: 2.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          counterText: '',
          errorText: _isValidEmail(_emailID.text) || _emailID.text.isEmpty
              ? null
              : 'Please enter a valid email address',
        ),
        onChanged: (_) {
          setState(() {});
        },
        onSubmitted: (_) {
          if (_isValidEmail(_emailID.text)) {
            FocusScope.of(context).unfocus();
          } else {
            //Fluttertoast.showToast(msg: "Please enter a valid email address");
            AppSnackBar.showGetXCustomSnackBar(
                message: 'Please enter a valid email address');
          }
        },
      ),
    );
  }

  Widget _buildSignUpButton(Global global) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: global.loadingSignup
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
              : Text("Sign Up",
                  style: TextStyle(fontSize: 18.sp, color: Colors.white)),
        ),
        onPressed: () async {
          List<ConnectivityResult> results =
              await Connectivity().checkConnectivity();

          if (results.contains(ConnectivityResult.none)) {
            AppSnackBar.showGetXCustomSnackBar(
              message: 'Please check your internet connection.',
            );
          } else {
            _handleSignup(global);
          }
        },
        style: ButtonStyle(
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          backgroundColor: WidgetStateProperty.all(Color(0XFF2c9ed9)),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18.0, left: 15.0, right: 15.0),
          child: Row(children: <Widget>[
            Expanded(child: Divider(color: Colors.black, thickness: 0.8)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text("OR", style: TextStyle(color: Colors.black)),
            ),
            Expanded(child: Divider(color: Colors.black, thickness: 0.8)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Text("Already Have an account?",
              style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () {
            Get.to(() => LoginPage());
          },
          child: Text("Login", style: TextStyle(color: Color(0XFF2c9ed9))),
        ),
      ],
    );
  }

  // void showAnimatedToast(String message) {
  //   Widget toast = StatefulBuilder(
  //     builder: (context, setState) {
  //       return TweenAnimationBuilder(
  //         tween: Tween<double>(begin: -50, end: 0), // Animation starts off-screen
  //         duration: const Duration(milliseconds: 500), // Animation duration
  //         builder: (context, value, child) {
  //           return Transform.translate(
  //             offset: Offset(0, value),
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
  //               decoration: BoxDecoration(
  //                 color: Colors.red,
  //                 borderRadius: BorderRadius.circular(8.0), // Slightly rounded corners
  //               ),
  //               child: Text(
  //                 message,
  //                 style: const TextStyle(color: Colors.white, fontSize: 16.0),
  //                 textAlign: TextAlign.center,
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
  //     toastDuration: const Duration(seconds: 3),
  //
  //   );
  // }

  // ignore: unused_element
  void _handleSignup1(Global global) {
    if (_userCd.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter User Code", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter User Code");
    } else if (_password.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter Password", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Password");
    } else if (_username.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter Username", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Username");
    } else if (_mobile.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter Mobile", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Mobile");
    } else if (_mobile.text.isNotEmpty && _mobile.text.length != 10) {
      // showAnimatedToast(
      //     message: "Please Enter 10 Digit Mobile Number", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(
          message: "Please Enter 10 Digit Mobile Number");
    } else if (_firmName.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter Firm Name", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Firm Name");
    } else if (_emailID.text.isEmpty) {
      //showAnimatedToast(message: "Please Enter Email Id", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Email Id");
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingsignup(true);
      AuthServices()
          .signup1(_userCd.text, _password.text, _username.text, _mobile.text,
              _firmName.text, _emailID.text, context)
          .then((value) {
        if (value == true) {
          print('Value' + value.toString());
          // showAnimatedToast(
          //     message: "Account Created Successfully", color: Colors.green);

          AppSnackBar.showGetXCustomSnackBar(
              message: "Account Created Successfully",
              backgroundColor: Colors.green);
          // Fluttertoast.showToast(msg: "Account Created Successfully");
          global.loadingsignup(false);
          Get.offAll(() => LoginPage());
        } else if (value == false) {
          //showAnimatedToast(message: "User already Exists", color: Colors.red);
          AppSnackBar.showGetXCustomSnackBar(message: "User already Exists");

          global.loadingsignup(false);
        } else {
          AppSnackBar.showGetXCustomSnackBar(
              message: "Signup failed. Please try again.");

          // showAnimatedToast(
          //     message: "Signup failed. Please try again.", color: Colors.red);
          // Fluttertoast.showToast(msg: "Signup failed. Please try again.");
          global.loadingsignup(false);
        }
      });
    }
  }

  void _handleSignup(Global global) {
    if (_userCd.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter User Code");
    } else if (_password.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Password");
    } else if (_username.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Username");
    } else if (_mobile.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Mobile");
    } else if (_mobile.text.isNotEmpty && _mobile.text.length != 10) {
      AppSnackBar.showGetXCustomSnackBar(
          message: "Please Enter 10 Digit Mobile Number");
    } else if (_firmName.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Firm Name");
    } else if (_emailID.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: "Please Enter Email Id");
    } else if (_emailID.text.isNotEmpty &&
        !Helper.isValidEmail(_emailID.text)) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please Enter Valid Email Id');
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingsignup(true);
      AuthServices()
          .signup(
        _userCd.text,
        _password.text,
        _username.text,
        _mobile.text,
        _firmName.text,
        _emailID.text,
        context,
      )
          .then((response) {
        global.loadingsignup(false);

        if (response.status) {
          if (response.data != null) {
            mobileNo.value = response.data!['user']['MOBILENO'];
            isVerified.value = response.data!['user']['IS_VERIFIED'];
          }

          // AppSnackBar.showGetXCustomSnackBar(
          //   message: "Account Created Successfully",
          //   backgroundColor: Colors.green,
          // );
          //
          // Get.offAll(() => LoginPage());
        } else {
          AppSnackBar.showGetXCustomSnackBar(
            message: response.message,
            backgroundColor: Colors.red,
          );
        }
      });
    }
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

  Future<void> fetchUserExits(String userCd) async {
    if (!await Network.isConnected()) {
      AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      return;
    }

    try {
      isUserExitsLoading(true);

      final uri = Uri.parse(AppConfig.checkUserURL).replace(
        queryParameters: {'userCd': userCd},
      );

      final response = await http.get(
        uri,
        headers: {
          'x-app-type': 'oms',
        },
      );

      final firmResponse = UserExitsResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );

      if (firmResponse.status == true &&
          (firmResponse.message == "User already exists" ||
              firmResponse.message == "User exists")) {
        userErrorMsg.value = 'User already exists';
      } else if (firmResponse.status == false &&
          firmResponse.message == "User does not exist") {
        userErrorMsg.value = '';
      }
    } catch (e) {
      userErrorMsg.value = '';
    } finally {
      isUserExitsLoading(false);
    }
  }

  void onClientCdChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (val.isNotEmpty) {
        fetchUserExits(val);
      }
    });
  }

  void verifyOTPValidation() {
    final Global global = Provider.of<Global>(context, listen: false);

    if (verifyOTPController.value.text.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter OTP.');
    } else if (verifyOTPController.value.text.isNotEmpty &&
        verifyOTPController.value.text.length < 6) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please enter a valid OTP.');
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      global.loadingsignup(true);

      AuthServices()
          .verifyOTP(
        mobileNo.value,
        verifyOTPController.value.text,
        context,
      )
          .then((value) {
        if (value != null) {
          global.loadingsignup(false);

          Navigator.pop(context);

          AppSnackBar.showGetXCustomSnackBar(
            message: 'Verify OTP successfully',
            backgroundColor: Colors.green,
          );
        } else {
          global.loadingsignup(false);
        }
      });
    }
  }

  void resendOTPValidation() {
    final Global global = Provider.of<Global>(context, listen: false);

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

    // final Global global = Provider.of<Global>(context, listen: false);
    //
    // if (verifyOTPController.value.text.isEmpty) {
    //   AppSnackBar.showGetXCustomSnackBar(message: 'Please enter OTP.');
    // } else if (verifyOTPController.value.text.isNotEmpty &&
    //     verifyOTPController.value.text.length < 6) {
    //   AppSnackBar.showGetXCustomSnackBar(message: 'Please enter a valid OTP.');
    // } else {
    //   FocusManager.instance.primaryFocus?.unfocus();
    //   global.loadingsignup(true);
    //
    //   Authservices().resendOTP(mobileNo.value, context).then((value) {
    //     if (value != null) {
    //       global.loadingsignup(false);
    //
    //       verifyOTPController.value.clear();
    //
    //       AppSnackBar.showGetXCustomSnackBar(
    //         message: 'OTP resent successfully',
    //         backgroundColor: Colors.green,
    //       );
    //     } else {
    //       global.loadingsignup(false);
    //     }
    //   });
    // }
  }

// mobileNo.value = responseData['data']['user']['SC_MOBILENO'];
// isVerified.value = responseData['data']['user']['IS_VERIFIED'];
// isVerified.value = response.data['data']['IS_VERIFIED'];
}
