import 'package:flutter/cupertino.dart';
import 'package:arham_corporation/providers/app_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() {
    getUserData();
    getSyncId();
    getSyncName();
    getCustId();
    checkSignIn();
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

  void checkSignIn() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _isSignedIn = sp.getBool('signed_in') ?? false;
    notifyListeners();
  }

  Future userSignout(context) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    sp.clear();

    Services().logout(context);

    AppProviders.disposeAllDisposableProviders(context);

    _isSignedIn = false;
    _role = null;
    _token = null;

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
      final uri = Uri.parse('${AppConfig.baseURL}users/children');
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
          print('[UserProvider] 👥 Children count: ${data.length} (hasChildren: $hasChildren)');
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
