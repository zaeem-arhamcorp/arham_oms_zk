import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/product/controller/product_controller.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/background_location_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() {
    // ⚠️ IMPORTANT: Do NOT call async methods here!
    // Use initializeAsync() instead for proper async initialization
  }

  String? _role;

  String? get role => _role;

  String? _token;

  String? get token => _token;

  bool _isSignedIn = false;

  bool get isSignedIn => _isSignedIn;

  bool showSignUp = true;

  String? _syncId;

  String? get syncId => _syncId;

  String? _syncName;

  String? get syncName => _syncName;

  String? _custId;

  String? get custId => _custId;

  /// ✅ Proper async initialization method - MUST be called on app startup
  /// Loads token, role, and sign-in state from SharedPreferences
  /// If no token exists, user is considered not signed in
  Future<void> initializeAsync() async {
    print('[UserProvider] 🔄 Starting async initialization...');
    try {
      // Load all data from SharedPreferences in parallel
      await Future.wait([
        getUserData(),
        getSyncId(),
        getSyncName(),
        getCustId(),
        checkSignIn(),
      ]);

      // ✅ Token-based session validation
      if (_token == null || _token!.isEmpty) {
        print('[UserProvider] ⚠️ No token found - marking user as signed out');
        _isSignedIn = false;
        notifyListeners();
      } else {
        print('[UserProvider] ✅ Token loaded successfully - session valid');
        // Profile will be loaded when SplashScreen reaches HomePage
      }

      print('[UserProvider] ✅ Async initialization completed');
    } catch (e, stack) {
      print('[UserProvider] ❌ Error during initialization: $e');
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'user_provider_init_failed',
      );
      // Ensure user is signed out on error
      _isSignedIn = false;
      _token = null;
      notifyListeners();
    }
  }

  changeShowSignUp(val) {
    showSignUp = val;
    notifyListeners();
  }

  Future saveCustId(custId) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("CustId", custId);
    _custId = custId;
    notifyListeners();
  }

  Future getCustId() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _custId = sp.getString("CustId");
    print("cust id " + _custId.toString());
    notifyListeners();
  }

  Future saveSyncId(syncId) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("SyncId", syncId);
    _syncId = syncId;
    notifyListeners();
  }

  Future getSyncId() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _syncId = sp.getString("SyncId");
    print("sunc id " + _syncId.toString());
    notifyListeners();
  }

  Future saveSyncName(syncName) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("SyncName", syncName);
    _syncName = syncName;
    notifyListeners();
  }

  Future getSyncName() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _syncName = sp.getString("SyncName");
    print("sync name " + _syncName.toString());
    notifyListeners();
  }

  Future saveUserData(role, token) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("role", role);
    await sp.setString("token", token);
    print('[UserProvider] ✅ Saved token to SharedPreferences: token=$token');
    _role = role;
    _token = token;
    await CrashlyticsService.logAction(
      'user_auth_data_saved',
      context: {'role': role?.toString() ?? ''},
    );
    notifyListeners();
  }

  Future getUserData() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _role = sp.getString("role");
    _token = sp.getString("token");
    notifyListeners();
  }

  Future setSignIn() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setBool('signed_in', true);
    _isSignedIn = true;
    notifyListeners();
  }

  Future<void> checkSignIn() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _isSignedIn = sp.getBool('signed_in') ?? false;
    notifyListeners();
  }

  Future userSignout(context) async {
    print('[UserProvider] 🔴 User logout initiated');
    await CrashlyticsService.logAction('user_logout_initiated');
    final logoutToken = _token;

    // Step 1: Stop background location tracking service
    try {
      print(
          '[UserProvider] 🛑 Stopping background location tracking service...');
      final backgroundService = BackgroundLocationService();
      await backgroundService.stopTracking(endTripOnServer: false);
      print('[UserProvider] ✅ Background tracking stopped');
    } catch (e) {
      print('[UserProvider] ⚠️ Error stopping tracking: $e');
    }

    // Step 2: Clear session-scoped profile and party state
    try {
      print('[UserProvider] 🧹 Clearing session state...');
      if (context.mounted) {
        Provider.of<ProfileProvider>(context, listen: false).disposeValues();
        Provider.of<PartyProvider>(context, listen: false).disposeValues();
      }
      print('[UserProvider] ✅ Profile and party state cleared');
    } catch (e) {
      print('[UserProvider] ⚠️ Error clearing profile/party state: $e');
    }

    // Step 3: Clear selected party and stockist selection from ProductController
    try {
      print('[UserProvider] 🧹 Clearing controller selection...');
      if (Get.isRegistered<ProductController>()) {
        final productController = Get.find<ProductController>();
        await productController.clearStockistSelection();
      }
      print('[UserProvider] ✅ Controller selection cleared');
    } catch (e) {
      print('[UserProvider] ⚠️ Error clearing controller selection: $e');
    }

    // Step 4: Clear SharedPreferences
    final SharedPreferences sp = await SharedPreferences.getInstance();
    print('[UserProvider] 🗑️ Clearing SharedPreferences');
    sp.clear();

    // Step 5: Call server logout using captured token (no context/provider lookup)
    try {
      print('[UserProvider] 📡 Calling server logout API...');
      await Services().logoutWithToken(logoutToken);
      print('[UserProvider] ✅ Server logout completed');
    } catch (e) {
      print('[UserProvider] ⚠️ Error in server logout: $e');
    }

    // Step 6: Dispose all providers
    // Note: Skip context-based disposal since widget tree is deactivated
    // Each provider should auto-cleanup when replaced or removed from widget tree
    print(
        '[UserProvider] 🧹 Skipping context-based provider disposal (widget tree deactivated)');

    // Step 7: Clear local user state
    _isSignedIn = false;
    _role = null;
    _token = null;
    _syncId = null;
    _syncName = null;
    _custId = null;

    await CrashlyticsService.setUserContext(
      userId: 'signed_out',
      userName: '',
      userEmail: '',
      userPhone: '',
      userRole: '',
    );

    print('[UserProvider] ✅ User logout completed');
    notifyListeners();
  }

  /// Check if current user is a parent user (has child users)
  Future<bool> hasChildren() async {
    print('[UserProvider] 🔍 Checking if user has children...');

    if (_token == null || _token!.isEmpty) {
      print('[UserProvider] ❌ Token is null or empty');
      return false;
    }

    try {
      final uri = Uri.parse('${AppConfig.childrenURL}');
      print('[UserProvider] 📡 Calling children API: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 5));

      print('[UserProvider] 📥 Response Status: ${response.statusCode}');
      print('[UserProvider] 📋 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded['data'];

        print('[UserProvider] ✅ Data type: ${data.runtimeType}');

        if (data is List) {
          final hasChildren = data.isNotEmpty;
          print(
              '[UserProvider] 👥 Children count: ${data.length} (hasChildren: $hasChildren)');
          return hasChildren;
        }
        print('[UserProvider] ❌ Data is not a list');
        return false;
      }

      print('[UserProvider] ❌ API returned status ${response.statusCode}');
      return false;
    } catch (e) {
      print('[UserProvider] ❌ Timeout or error checking children: $e');
      return false;
    }
  }
}
