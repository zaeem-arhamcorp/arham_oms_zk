import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkHelper {
  static Future<bool> hasInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    // No network interface at all
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    // Check real internet access
    return await InternetConnectionChecker.instance.hasConnection;
  }
}