import 'package:flutter/material.dart';

class AppConfig {
  //9974058361 Ganesh Pharma
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

  //9033881931 Rizwan Ansari - 1       Master
  //9227451051 Mubassira - 2           Master
  //9723760786 Zaeem Kadri - 1         Master
  //9875 Abrar - 98                    Parent
  //9824747862 Firoj Khan - 1          Child

  //Nevil Pharma
  //9033546913 Mahesh Patadiya - Password: 101
  //7383169201 Mehul Dholariya

  //        Old Commit                                 New Commit
  //77f08058cf3f204c343128a5b54e2c4786eee775 8d57534bdd366b9607b0f73d16b6e5f1a5b7f1eb

  static const String baseURL = "http://192.168.1.12:4002/api/"; //TODO: Local

  // static const String baseURL =
  //       "https://apidev.arhamcorp.in/api/"; //TODO: Stage

  // static const String baseURL =
  //     "https://api.arhamcorp.in/api/"; //TODO: Production

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
  static String transactionUploadImageURL =
      "${baseURL}transaction-images/upload";
  static String generateReferralCodeURL = "${baseURL}referral/generate-code";

  static const String createAccounttURL = '${baseURL}master-entry/account';
  static const String uploadImageURL =
      '${baseURL}master-entry/account/upload-image';
  static const String uploadAccountImageURL = '${baseURL}account-image';

  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'AIzaSyB3srmIjv8Pux0hMn-Kd4Nqj5xdonh05dM',
  );

  // User status & heartbeat
  static const String heartbeatURL = '${baseURL}heartbeat';

  static const String tripStartURL = '${baseURL}location/trip/start';
  static const String tripEndURL = '${baseURL}location/trip/end';
  static const String childrenURL = '${baseURL}users/children';
  // static const String timelineURL = '${baseURL}timeline';

  // Task Management APIs
  static const String getStockistsURL = '${baseURL}products/party?groupCd=136';
  static const String getMyDepartmentsURL = '${baseURL}my-departments';
  static const String assignIssueURL = '${baseURL}dealer-flow/issues';
}
