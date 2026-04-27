import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/models/signupresponse.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class AuthServices {
  Future<dynamic> changeFirmLogin(
      String syncId, String tempToken, context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    // Body as JSON
    Map<String, dynamic> body = {
      "syncId": syncId,
    };

    print(body);

    try {
      final http.Response response = await http.post(
        Uri.parse(AppConfig.baseURL + "change-firm"),
        headers: {
          "Authorization": "Bearer ${tempToken}",
          'x-app-type': 'oms',
          "Content-Type": "application/json",
          // Set Content-Type for JSON encoding
        },
        body: jsonEncode(body), // Encode body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body); // Parse response to JSON
      } else {
        global.loadingfetchlogin(false);
        final errorMessage =
            json.decode(response.body)["message"] ?? "An error occurred";
        //Fluttertoast.showToast(msg: errorMessage);
        AppSnackBar.showGetXCustomSnackBar(message: errorMessage);
        return null;
      }
    } catch (e, stack) {
      global.loadingfetchlogin(false);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      print("Error: $e");
      CrashlyticsService.recordNonFatal(e, stack);
      return null;
    }
  }

  Future<dynamic> performLoginWithUserCd(email, password, context) async {
    final Global global = Provider.of<Global>(context, listen: false);
    Map bod = {
      "userName": email,
      "password": password,
    };

    print(bod);

    try {
      // final http.Response response =
      //     //await http.post(Uri.parse(AppConfig.baseUrl + "login"), body: bod);
      //     await http.post(Uri.parse(AppConfig.baseUrl + "login"),
      //         body: bod);

      final http.Response response = await http.post(
        Uri.parse(AppConfig.baseURL + "login"),
        headers: {
          'x-app-type': 'oms',
        },
        body: bod, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        global.loadinglogin(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      global.loadinglogin(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices login ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  //TODO : OLD CODE
  Future<bool?> signup1(
      userCd, password, username, mobileno, firmName, emailId, context) async {
    final Global global = Provider.of<Global>(context, listen: false);
    Map bod = {
      "userCd": userCd,
      "password": password,
      "userName": username,
      "mobileNo": mobileno,
      "firm_name": firmName,
      "email": emailId,
    };

    print(bod);
    try {
      final http.Response response = await http.post(
        Uri.parse(AppConfig.baseURL + "signup"),
        headers: {
          'x-app-type': 'oms',
        },
        body: bod, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        if (json.decode(response.body)["message"] == 'User already Exists') {
          return false;
        } else {
          return true;
        }
      } else {
        global.loadingsignup(false);
        print("Sign Up Error Msg : " + json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        return false;
      }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices login ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
    return null;
  }

  //TODO : NEW CODE
  Future<SignupResponse> signup(
    userCd,
    password,
    username,
    mobileno,
    firmName,
    emailId,
    referralCode,
    context,
  ) async {
    Map<String, String> body = {
      "userCd": userCd,
      "password": password,
      "userName": username,
      "mobileNo": mobileno,
      "firm_name": firmName,
      "email": emailId,
      "type": "web",
    };

    // Only include referral_code when a non-empty value is provided
    try {
      final ref = referralCode?.toString().trim();
      if (ref != null && ref.isNotEmpty) {
        body['referral_code'] = ref;
      }
    } catch (_) {}

    try {
      final response = await http.post(
        Uri.parse("${AppConfig.baseURL}signup"),
        headers: {'x-app-type': 'oms'},
        body: body,
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200) {
        return SignupResponse(
          status: decoded['message'] != 'User already Exists',
          message: decoded['message'],
          data: decoded['data'],
        );
      } else {
        return SignupResponse(
          status: false,
          message: decoded['message'] ?? "Signup failed",
        );
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      return SignupResponse(
        status: false,
        message: "Something went wrong",
      );
    }
  }

  Future<Map<String, dynamic>> validateReferralCode(referralCode) async {
    try {
      final requestUrl = AppConfig.validateReferralCodeUrl;
      final requestPayload = {
        'app_type': 'oms',
        'referral_code': referralCode?.toString() ?? '',
      };

      print('[AuthServices][validateReferralCode] URL: $requestUrl');
      print(
        '[AuthServices][validateReferralCode] Payload: ${jsonEncode(requestPayload)}',
      );

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestPayload),
      );

      print(
        '[AuthServices][validateReferralCode] Response (${response.statusCode}): ${response.body}',
      );

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final status = decoded is Map && decoded['status'] is bool
            ? decoded['status'] as bool
            : true;

        return {
          'status': status,
          'message': decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : '',
        };
      }

      return {
        'status': false,
        'message': decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Invalid referral code',
      };
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      return {
        'status': false,
        'message': 'Unable to validate referral code',
      };
    }
  }

  Future<dynamic> verifyOTP(
      String mobileNumber, String otp, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);
    try {
      //if (await Network.isConnected()) {
      Map<String, dynamic> param = {'mobileNo': mobileNumber, 'otp': otp};

      final http.Response response = await http.post(
        Uri.parse(AppConfig.verifyOTPURL),
        headers: {
          'x-app-type': 'oms',
        },
        body: param, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        global.loadinglogin(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }
      // } else {
      //   AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      // }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Verify OTP ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  Future<dynamic> resendOTP(String mobileNumber, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      //if (await Network.isConnected()) {
      Map<String, dynamic> param = {'mobileNo': mobileNumber};

      final http.Response response = await http.post(
        Uri.parse(AppConfig.resendOTPURL),
        headers: {
          'x-app-type': 'oms',
        },
        body: param, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        global.loadinglogin(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }

      // } else {
      //   AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      // }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Resend OTP ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  //TODO : NOT USED
  Future<dynamic> verifiedOTP(String mobileNumber, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      if (await Network.isConnected()) {
        Map<String, dynamic> param = {'mobileNo': mobileNumber};
        //Map<String, dynamic> param = {'UserCd': mobileNumber};

        final http.Response response = await http.post(
          Uri.parse(AppConfig.isVerifiedOTPURL),
          headers: {
            'x-app-type': 'oms',
          },
          body: param, // Encode the body as JSON
        );

        print(response.body);

        if (response.statusCode == 200) {
          return response.body;
        } else {
          global.loadinglogin(false);
          AppSnackBar.showGetXCustomSnackBar(
              message: json.decode(response.body)["message"]);
          //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Is Verified Mobile OTP ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  Future<Map<String, dynamic>?> checkVerifiedWithCodeOTP(
      String value, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      if (await Network.isConnected()) {
        final uri = Uri.parse(AppConfig.isVerifiedOTPURL).replace(
          queryParameters: {'userCd': value},
        );

        final http.Response response = await http.get(
          uri,
          headers: {'x-app-type': 'oms'},
        );

        print(uri.toString());
        print(response.body);

        if (response.statusCode == 200) {
          return json.decode(response.body); // return Map
        } else {
          global.loadinglogin(false);
          AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
          );
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message: Constants.networkMsg,
        );
      }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(
        message: "Something went wrong",
      );
      print("Error in AuthServices Is Verified USER CODE ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
    return null;
  }

  Future<dynamic> performLoginWithMobile(
      String mobileNumber, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      //if (await Network.isConnected()) {
      Map<String, dynamic> param = {'mobileNo': mobileNumber};

      final http.Response response = await http.post(
        Uri.parse(AppConfig.loginWithMobileURL),
        headers: {
          'x-app-type': 'oms',
        },
        body: param, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        global.loadinglogin(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }

      // } else {
      //   AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      // }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Login With Number ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  Future<dynamic> performLoginWithMobileOTP(
    String mobileNumber,
    String otp,
    BuildContext context,
  ) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      //if (await Network.isConnected()) {
      Map<String, dynamic> param = {'mobileNo': mobileNumber, 'otp': otp};

      final http.Response response = await http.post(
        Uri.parse(AppConfig.loginWithMobileVerifyOTPURL),
        headers: {
          'x-app-type': 'oms',
        },
        body: param, // Encode the body as JSON
      );

      print(response.body);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        global.loadinglogin(false);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
      }
      // } else {
      //   AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      // }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Login With Number & OTP ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  Future<dynamic> forgotPassword(
      String mobileNumber, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      if (await Network.isConnected()) {
        Map<String, dynamic> param = {'mobileNo': mobileNumber};

        final http.Response response = await http.post(
          Uri.parse(AppConfig.forgotPasswordURL),
          headers: {
            'x-app-type': 'oms',
          },
          body: param, // Encode the body as JSON
        );

        print(response.body);

        if (response.statusCode == 200) {
          return response.body;
        } else {
          global.loadinglogin(false);
          AppSnackBar.showGetXCustomSnackBar(
              message: json.decode(response.body)["message"]);
          //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Forgot Password ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }

  Future<Map<String, dynamic>?> checkVerifiedMobileOTP(
      String value, BuildContext context) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      if (await Network.isConnected()) {
        final uri = Uri.parse(AppConfig.isVerifiedOTPURL).replace(
          queryParameters: {'mobileNo': value},
        );

        final http.Response response = await http.get(
          uri,
          headers: {'x-app-type': 'oms'},
        );

        print(uri.toString());
        print(response.body);

        if (response.statusCode == 200) {
          return json.decode(response.body); // return Map
        } else {
          global.loadinglogin(false);
          AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
          );
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message: Constants.networkMsg,
        );
      }
    } catch (e, stack) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(
        message: "Something went wrong",
      );
      print("Error in AuthServices Is Verified MOBILE NUMBER ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
    return null;
  }

  Future<dynamic> resetPassword(
    String mobileNumber,
    String otp,
    String newPassword,
    BuildContext context,
  ) async {
    final Global global = Provider.of<Global>(context, listen: false);

    try {
      if (await Network.isConnected()) {
        Map<String, dynamic> param = {
          'mobileNo': mobileNumber,
          "otp": otp,
          "newPassword": newPassword
        };

        final http.Response response = await http.post(
          Uri.parse(AppConfig.resetPasswordURL),
          headers: {
            'x-app-type': 'oms',
          },
          body: param, // Encode the body as JSON
        );

        print(response.body);

        if (response.statusCode == 200) {
          return response.body;
        } else {
          global.loadinglogin(false);
          AppSnackBar.showGetXCustomSnackBar(
              message: json.decode(response.body)["message"]);
          //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        }
      } else {
        AppSnackBar.showGetXCustomSnackBar(message: Constants.networkMsg);
      }
    } catch (e, stack) {
      global.loadinglogin(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Reset Password ${e.toString()}");
      CrashlyticsService.recordNonFatal(e, stack);
    }
  }
}
