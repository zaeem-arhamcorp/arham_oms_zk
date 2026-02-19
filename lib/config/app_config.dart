import 'package:flutter/material.dart';

class AppConfig {
  //9428411214
  //7990036174
  //9033881931

  //9913897011  Bharat Gohil
  //9558410111

  //9978959456  Avadip
  //9978959456

  //9898767654 Latest User
  //9227774034
  //8140263919
  //3919

  //static const String baseURL = "http://192.168.1.12:4002/api/"; //TODO: Local

  // static const String baseURL =
  //     "https://apidev.arhamcorp.in/api/"; //TODO: Stage

  static const String baseURL =
      "https://api.arhamcorp.in/api/"; //TODO: Production

  //static const String baseURL = "https://pharma.skyhubs.in/api/";
  static const String baseURLReport = "${baseURL}reports/";

  static const String masteruser = "M";
  static const String operatoruser = "O";

  static const Color mainColor = Color(0XFF1C22C3);
  static const Color primaryColor = Color(0XFF2c9ed9);

  static String loginWithMobileURL = "${baseURL}login-mobile";
  static String loginWithMobileVerifyOTPURL = "${baseURL}verify-otp-mobile";
  static String verifyOTPURL = "${baseURL}verify-otp";
  static String resendOTPURL = "${baseURL}resend-otp";
  static String isVerifiedOTPURL = "${baseURL}isverified";
  static String forgotPasswordURL = "${baseURL}forgot-password";
  static String resetPasswordURL = "${baseURL}reset-password";
  static String changePasswordURL = "${baseURL}change-password";
  static String checkUserURL = "${baseURL}check-user";
  static String transactionUploadImageURL = "${baseURL}transaction-images/upload";
}
