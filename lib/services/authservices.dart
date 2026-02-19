import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/constants/constants.dart';
import 'package:arham_corporation/models/signupresponse.dart';
import 'package:arham_corporation/network.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/global.dart';
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
    } catch (e) {
      global.loadingfetchlogin(false);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      print("Error: $e");
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
    } catch (e) {
      global.loadinglogin(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices login ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices login ${e.toString()}");
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
    context,
  ) async {
    Map<String, String> body = {
      "userCd": userCd,
      "password": password,
      "userName": username,
      "mobileNo": mobileno,
      "firm_name": firmName,
      "email": emailId,
    };

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
    } catch (e) {
      return SignupResponse(
        status: false,
        message: "Something went wrong",
      );
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Verify OTP ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Resend OTP ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Is Verified Mobile OTP ${e.toString()}");
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
          return json.decode(response.body); // ✅ return Map
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(
        message: "Something went wrong",
      );
      print("Error in AuthServices Is Verified USER CODE ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Login With Number ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Login With Number & OTP ${e.toString()}");
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Forgot Password ${e.toString()}");
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
          return json.decode(response.body); // ✅ return Map
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
    } catch (e) {
      global.loadingsignup(false);
      AppSnackBar.showGetXCustomSnackBar(
        message: "Something went wrong",
      );
      print("Error in AuthServices Is Verified MOBILE NUMBER ${e.toString()}");
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
    } catch (e) {
      global.loadinglogin(false);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in AuthServices Reset Password ${e.toString()}");
    }
  }
}
