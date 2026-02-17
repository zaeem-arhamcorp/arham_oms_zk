import 'package:flutter/cupertino.dart';
import 'package:arham_corporation/providers/app_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  UserProvider() {
    getUserData();
    getSyncId();
    getSyncName();
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

  changeShowSignUp(val) {
    showSignUp = val;
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
}
