import 'dart:io' show InternetAddress, Platform;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum NetworkSpeed {
  unknown,
  slow,
  moderate,
  fast,
}

class Network {
  static Future<bool> isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    // ✅ Check for Web platform (dart:io not available)
    if (kIsWeb) {
      // Trick to detect Flutter Web
      //return await _checkInternetWeb();
      var networkSpeed = _inferNetworkSpeed();
      return networkSpeed == NetworkSpeed.fast ||
          networkSpeed == NetworkSpeed.moderate;
    }

    // ✅ Check for Android & iOS
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      var networkSpeed = _inferNetworkSpeed();
      return networkSpeed == NetworkSpeed.fast ||
          networkSpeed == NetworkSpeed.moderate;
    }

    // ✅ Check for Windows
    if (Platform.isWindows) {
      return await _checkInternetWindows();
    }

    return false;
  }

  // 🌐 **For Web Browsers: Uses HTTP Request**
  // ignore: unused_element
  static Future<bool> _checkInternetWeb() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 🖥️ **For Windows: Uses InternetAddress.lookup**
  static Future<bool> _checkInternetWindows() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 📶 **Network Speed Check**
  static NetworkSpeed _inferNetworkSpeed() {
    if (Duration.zero < const Duration(milliseconds: 500)) {
      return NetworkSpeed.fast;
    } else if (const Duration(milliseconds: 500) <
        const Duration(milliseconds: 1500)) {
      return NetworkSpeed.moderate;
    } else {
      return NetworkSpeed.slow;
    }
  }
}
