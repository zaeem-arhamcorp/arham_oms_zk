import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:flutter/cupertino.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:get/get.dart';
import '../services/database_helper.dart';
import '../helper/network_helper.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/profileModal.dart';
import '../models/settingmodal.dart';
import '../services/services.dart';
import '../views/loginpage.dart';

class ProfileProvider extends DisposableProvider {
  DataProfile? _data;

  DataProfile? get data => _data;

  String YN = "";
  String ACC_NAME = "";
  String ACC_CD = "";

  // Holds a warning message from the order placement API (e.g. order limit warnings).
  // Displayed as a snackbar on the homescreen after the order success flow.
  String? _pendingWarning;
  String? get pendingWarning => _pendingWarning;

  void setPendingWarning(String warning) {
    _pendingWarning = warning;
    notifyListeners();
  }

  void clearPendingWarning() {
    _pendingWarning = null;
    notifyListeners();
  }

  String? _userCode;

  String? get userCode => _userCode;

  String? _userName;

  String? get userName => _userName;

  Future saveUserCode(userCode) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("UserCode", userCode);
    _userCode = userCode;
    notifyListeners();
  }

  Future getUserCode() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _userCode = sp.getString("UserCode");
    print("User Code " + _userCode.toString());
    notifyListeners();
  }

  Future saveUserName(userName) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("UserName", userName);
    _userName = userName;
    notifyListeners();
  }

  Future getUserName() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _userName = sp.getString("UserName");
    print("User Name " + _userName.toString());
    notifyListeners();
  }

  change(accname, accid) {
    print(";;;;;;;;;;;;;;");
    ACC_NAME = accname;
    ACC_CD = accid;
    notifyListeners();
  }

  Future getProfile(BuildContext context, {id}) async {
    YN = "";
    ACC_NAME = "";
    ACC_CD = "";
    if (_data != null) {
      _data = null;
    }
    notifyListeners();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final bool online = await NetworkHelper.hasInternet();
    if (!online) {
      // Load cached profile if available
      try {
        final cached = await DatabaseHelper().getCachedProfileJson();
        if (cached != null && cached.isNotEmpty) {
          _data = profileModalFromJson(cached).data;
          // populate simple fields
          YN = (data?.profileSettings.any(
                      (e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                  false)
              ? 'Y'
              : 'N';

          ACC_NAME = data!.orderStartParty == null
              ? ""
              : data!.orderStartParty!.accName.toString();
          ACC_CD = data!.orderStartParty == null
              ? ""
              : data!.orderStartParty!.accCd.toString();

          // Restore username and user code from SharedPreferences
          await getUserCode();
          await getUserName();

          if (id == null) {
            if (YN == "Y") {
              pp.changePunchInOutParty(ACC_NAME, ACC_CD, context, id: 5);
            }
          }
          notifyListeners();
          return;
        }
      } catch (e) {
        print('Failed to load cached profile: $e');
      }
      // No cache available; bail out
      return;
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "profile"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "profile");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        _data = profileModalFromJson(response.body).data;

        // Cache profile for offline
        try {
          await DatabaseHelper().cacheProfileJson(response.body);
        } catch (e) {
          print('Failed to cache profile: $e');
        }

        saveUserCode(_data!.userCd.toString());
        saveUserName(_data!.userName.toString());
        print('Profile Data :' + response.body);

        getUserCode();
        getUserName();

        YN = (data?.profileSettings
                    .any((e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                false)
            ? 'Y'
            : 'N';

        ACC_NAME = data!.orderStartParty == null
            ? ""
            : data!.orderStartParty!.accName.toString();
        ACC_CD = data!.orderStartParty == null
            ? ""
            : data!.orderStartParty!.accCd.toString();
        if (id == null) {
          if (YN == "Y") {
            pp.changePunchInOutParty(ACC_NAME, ACC_CD, context, id: 5);
          }
        }
        notifyListeners();
      } else {
        ub.userSignout(context).then((value) {
          print("Profile Page Call Before Logout");
          Get.offAll(() => LoginPage());
          print("Profile Page Call After Logout");
        });
      }
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PerofileProvider getProfile  ${e.toString()}");
    }
    notifyListeners();
  }

  /// Load settings from API (online) or local cache (offline)
  /// Updates _data.profileSettings with the loaded settings
  Future loadSettings(BuildContext context) async {
    try {
      final bool online = await NetworkHelper.hasInternet();

      if (online) {
        // Fetch settings from API when online
        print('[SETTINGS] Loading settings from API (online)');
        final SettingModal? settingResponse =
            await Services().getSettings(context);

        if (settingResponse != null && settingResponse.data.isNotEmpty) {
          // Update profile settings
          if (_data != null) {
            _data!.profileSettings = settingResponse.data;
          }

          // Cache settings for offline use
          try {
            final List<Map<String, dynamic>> settingsMaps =
                settingResponse.data.map((s) => s.toJson()).toList();
            await DatabaseHelper().cacheSettings(settingsMaps);
            print(
                '[SETTINGS] Cached ${settingsMaps.length} settings for offline');
          } catch (e) {
            print('[SETTINGS] Failed to cache settings: $e');
          }
        } else {
          print('[SETTINGS] No settings data received from API');
        }
      } else {
        // Load settings from local cache when offline
        print('[SETTINGS] Loading settings from local cache (offline)');
        try {
          final List<Map<String, dynamic>> cachedSettings =
              await DatabaseHelper().getAllSettings();

          if (cachedSettings.isNotEmpty) {
            // Convert cached maps to DatumSettings objects
            final List<DatumSettings> settingsList =
                cachedSettings.map((s) => DatumSettings.fromJson(s)).toList();

            // Update profile settings
            if (_data != null) {
              _data!.profileSettings = settingsList;
            }
            print(
                '[SETTINGS] Loaded ${settingsList.length} settings from cache');
          } else {
            print('[SETTINGS] No cached settings available');
          }
        } catch (e) {
          print('[SETTINGS] Failed to load cached settings: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      print('[SETTINGS] Error in loadSettings: $e');
    }
  }

  @override
  disposeValues() {
    _data = null;
    notifyListeners();
  }
}
