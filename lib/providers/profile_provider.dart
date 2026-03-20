import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/services/location_service.dart';
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
import '../services/sync_service.dart';
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
    // NOTE: Do NOT clear _data, YN, ACC_NAME, ACC_CD or call notifyListeners()
    // before the network response. Doing so causes the UI to lose all state
    // (punch button disappears, Start/End Order breaks, partyCd becomes empty).
    // These values will be overwritten once the response arrives.
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final bool online = await NetworkHelper.hasInternet();
    if (!online) {
      // Load cached profile if available
      try {
        final cached = await DatabaseHelper().getCachedProfileJson();
        if (cached != null && cached.isNotEmpty) {
          _data = profileModalFromJson(cached).data;
          _ensureLegacyModuleNosFromModulesList();
          // populate simple fields
          YN = (data?.profileSettings.any(
                      (e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                  false)
              ? 'Y'
              : 'N';

          // Restore username and user code from SharedPreferences
          await getUserCode();
          await getUserName();

          // Restore punch state from local locations table (today's punches)
          try {
            final locService = LocationService();
            await _restorePunchStateAndAutoCloseIfNeeded(
              ub: ub,
              locService: locService,
              canAutoPunchOut: false,
              logTag: '[PROFILE-OFFLINE]',
            );
          } catch (e) {
            print('[PROFILE-OFFLINE] ❌ Failed to restore punch state: $e');
          }

          // Restore order session state from local order_tracking table
          try {
            final syncIdInt = int.tryParse(ub.syncId ?? '0') ?? 0;
            if (syncIdInt > 0) {
              final trackings =
                  await DatabaseHelper().getTodayOrderTrackings(syncIdInt);
              print(
                  '[PROFILE-OFFLINE] 🔍 Found ${trackings.length} order trackings for today');
              if (trackings.isNotEmpty) {
                final last = trackings.last;
                final trackingType = (last['tracking_type'] ?? '').toString();
                final accCd = (last['ACC_CD'] ?? '').toString();
                final remark = (last['REMARK'] ?? '').toString();
                print(
                    '[PROFILE-OFFLINE]   Last order tracking: type=$trackingType, ACC_CD=$accCd, REMARK=$remark');

                if (trackingType == '1' && remark == 'IN') {
                  // Active order session - restore party info
                  pp.punchInOutPartyId = accCd;
                  // Try to find party name from cache, fallback to current ACC_NAME if already set
                  var partyName = ACC_NAME; // Start with current value
                  try {
                    final cached = await DatabaseHelper().getCachedParties();
                    for (var row in cached) {
                      if (row['acc_cd'].toString() == accCd) {
                        partyName = row['name'] ?? ACC_NAME;
                        break;
                      }
                    }
                  } catch (e) {
                    print('[PROFILE-OFFLINE] Could not load party cache: $e');
                  }
                  pp.punchInOutParty = partyName;
                  // Set ProfileProvider ACC_Name and ACC_CD for this session
                  this.change(partyName, accCd);
                  print(
                      '[PROFILE-OFFLINE] ✅ Restored active order session: party=$accCd, name="$partyName"');
                } else if (trackingType == '3' && remark == 'OUT') {
                  // Order ended - clear party info
                  pp.punchInOutParty = '';
                  pp.punchInOutPartyId = '';
                  this.change('', '');
                  print(
                      '[PROFILE-OFFLINE] ✅ Restored ended order session (cleared party)');
                }
              }
            }
          } catch (e) {
            print('[PROFILE-OFFLINE] ❌ Failed to restore order state: $e');
          }
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

        // Keep module access firm-specific after firm switch.
        await _applyFirmModuleFilter(ub);

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

        getUserCode();
        getUserName();

        // Restore punch state from local locations table (today's punches)
        // This ensures the punch button reflects the last punch action even
        // when the server profile doesn't have that state yet
        try {
          final locService = LocationService();
          await _restorePunchStateAndAutoCloseIfNeeded(
            ub: ub,
            locService: locService,
            canAutoPunchOut: true,
            logTag: '[PROFILE-ONLINE]',
          );
        } catch (e) {
          print('[PROFILE-ONLINE] ❌ Failed to restore punch state: $e');
        }

        // Restore order session state from local order_tracking table
        try {
          final syncIdInt = int.tryParse(ub.syncId ?? '0') ?? 0;
          print('[PROFILE-ONLINE] 🔍 Checking order state: syncId=$syncIdInt');
          if (syncIdInt > 0) {
            final trackings =
                await DatabaseHelper().getTodayOrderTrackings(syncIdInt);
            print(
                '[PROFILE-ONLINE] 📊 Found ${trackings.length} order trackings for today (syncId=$syncIdInt)');
            if (trackings.isNotEmpty) {
              for (var t in trackings) {
                print(
                    '[PROFILE-ONLINE]   Tracking: type=${t['tracking_type']}, ACC_CD=${t['ACC_CD']}, REMARK=${t['REMARK']}, time=${t['VOUCH_TIME']}');
              }
              final last = trackings.last;
              final trackingType = (last['tracking_type'] ?? '').toString();
              final accCd = (last['ACC_CD'] ?? '').toString();
              final remark = (last['REMARK'] ?? '').toString();
              print(
                  '[PROFILE-ONLINE]   🎯 Last order tracking: type="$trackingType", ACC_CD="$accCd", REMARK="$remark"');

              if (trackingType == '1' && remark == 'IN') {
                // Active order session - restore party info
                pp.punchInOutPartyId = accCd;
                // Try to find party name from cache, fallback to current ACC_NAME if already set
                var partyName = ACC_NAME; // Start with current value
                try {
                  final cached = await DatabaseHelper().getCachedParties();
                  for (var row in cached) {
                    if (row['acc_cd'].toString() == accCd) {
                      partyName = row['name'] ?? ACC_NAME;
                      break;
                    }
                  }
                } catch (e) {
                  print('[PROFILE-ONLINE] Could not load party cache: $e');
                }
                pp.punchInOutParty = partyName;
                // Set ProfileProvider ACC_Name and ACC_CD for this session
                this.change(partyName, accCd);
                print(
                    '[PROFILE-ONLINE] ✅ Restored active order session: party=$accCd, name="$partyName"');
              } else if (trackingType == '3' && remark == 'OUT') {
                // Order ended - clear party info
                pp.punchInOutParty = '';
                pp.punchInOutPartyId = '';
                this.change('', '');
                print(
                    '[PROFILE-ONLINE] ✅ Restored ended order session (cleared party)');
              } else {
                print(
                    '[PROFILE-ONLINE] ⚠️ Last tracking type/remark combo not matched (type=$trackingType, remark=$remark). Leaving as-is.');
              }
            } else {
              print(
                  '[PROFILE-ONLINE] ⚠️ No order trackings found for syncId=$syncIdInt');
            }
          } else {
            print(
                '[PROFILE-ONLINE] ⚠️ syncId=$syncIdInt, skipping order state check');
          }
        } catch (e) {
          print('[PROFILE-ONLINE] ❌ Failed to restore order state: $e');
        }

        // Trigger sync of pending order trackings (IN/OUT) if any exist
        try {
          final db = DatabaseHelper();
          final pendingTrackings = await db.getPendingOrderTrackings();
          if (pendingTrackings.isNotEmpty && ub.token != null) {
            print(
                '[PROFILE-ONLINE] 🔄 Found ${pendingTrackings.length} pending order tracking(s) — triggering sync');
            // Import and call sync service to push pending trackings
            _triggerOrderTrackingSync(ub.token!);
          }
        } catch (e) {
          print(
              '[PROFILE-ONLINE] ⚠️ Failed to trigger order tracking sync: $e');
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
      print("Error in ProfileProvider getProfile  ${e.toString()}");
    }
    notifyListeners();
  }

  /// Load settings from API (online) or local cache (offline)
  /// Updates _data.profileSettings with the loaded settings
  Future loadSettings(BuildContext context) async {
    try {
      if (!context.mounted) {
        print('[SETTINGS] Skipping loadSettings: context is not mounted');
        return;
      }

      final bool online = await NetworkHelper.hasInternet();

      if (online) {
        if (!context.mounted) {
          print('[SETTINGS] Aborting online settings load: context disposed');
          return;
        }

        // Fetch settings from API when online
        print('[SETTINGS] Loading settings from API (online)');
        final SettingModal? settingResponse =
            await Services().getSettings(context);

        if (settingResponse != null && settingResponse.data.isNotEmpty) {
          // Update profile settings (MERGE instead of replace to preserve punchInOut)
          if (_data != null) {
            // Remove old settings that conflict with new ones (same 'variable' name)
            _data!.profileSettings.removeWhere((old) => settingResponse.data
                .any((new_) => new_.variable == old.variable));
            // Add new settings alongside existing ones
            _data!.profileSettings.addAll(settingResponse.data);
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

            // Update profile settings (MERGE instead of replace to preserve punchInOut)
            if (_data != null) {
              // Remove old settings that conflict with cached ones (same 'variable' name)
              _data!.profileSettings.removeWhere((old) =>
                  settingsList.any((new_) => new_.variable == old.variable));
              // Add cached settings alongside existing ones
              _data!.profileSettings.addAll(settingsList);
            }
            print(
                '[SETTINGS] Loaded ${settingsList.length} settings from cache (merged)');
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

  /// Update local punch-in state and notify listeners.
  /// Used by UI to reflect punch-in/out immediately.
  void setPunchState(bool isIn) {
    if (_data != null) {
      _data!.isPunchIn = isIn;
      notifyListeners();
    }
  }

  Future<void> _applyFirmModuleFilter(UserProvider ub) async {
    _ensureLegacyModuleNosFromModulesList();

    final selectedSyncId = ub.syncId?.trim();
    final token = ub.token?.trim();

    if (selectedSyncId == null || selectedSyncId.isEmpty) {
      print('[PROFILE-ONLINE] ⚠️ Firm module filter skipped: syncId is empty');
      return;
    }

    if (token == null || token.isEmpty) {
      print('[PROFILE-ONLINE] ⚠️ Firm module filter skipped: token is empty');
      return;
    }

    final modules = _data?.modulesList;
    if (modules == null || modules.isEmpty) {
      print(
          '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: no modules in profile');
      return;
    }

    try {
      final http.Response firmResponse = await http.get(
        Uri.parse(AppConfig.baseURL + 'firm'),
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      );

      if (firmResponse.statusCode != 200) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: /firm status=${firmResponse.statusCode}');
        return;
      }

      print('[PROFILE-ONLINE] /firm raw data ${firmResponse.body}');

      final decoded = json.decode(firmResponse.body);
      final List<dynamic> firms =
          decoded['data'] is List ? decoded['data'] : [];

      Map<String, dynamic>? selectedFirm;
      for (final firm in firms) {
        if (firm is Map<String, dynamic> &&
            (firm['SYNC_ID']?.toString().trim() ?? '') == selectedSyncId) {
          selectedFirm = firm;
          break;
        }
      }

      if (selectedFirm == null) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: selected firm $selectedSyncId not found in /firm');
        return;
      }

      print(
          '[PROFILE-ONLINE] Selected firm raw for syncId=$selectedSyncId => $selectedFirm');

      final moduleNosRaw = selectedFirm['MODULE_NOS']?.toString().trim() ?? '';
      if (moduleNosRaw.isEmpty) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: MODULE_NOS empty for syncId=$selectedSyncId');
        return;
      }

      final Set<String> allowedModuleNos = moduleNosRaw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      if (allowedModuleNos.isEmpty) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: parsed MODULE_NOS is empty');
        return;
      }

      final before = _data!.modulesList!.length;
      _data!.modulesList = _data!.modulesList!
          .where((m) => allowedModuleNos.contains((m.mODULENO ?? '').trim()))
          .toList();
      final after = _data!.modulesList!.length;

      _ensureLegacyModuleNosFromModulesList();
      print(
          '[PROFILE-ONLINE] ✅ Applied firm module filter for syncId=$selectedSyncId (before=$before, after=$after)');
    } catch (e) {
      print('[PROFILE-ONLINE] ❌ Failed to apply firm module filter: $e');
    }
  }

  void _ensureLegacyModuleNosFromModulesList() {
    if (_data == null) return;
    if (_data!.moduleNos.isNotEmpty) return;

    final modules = _data!.modulesList ?? <Modules>[];
    if (modules.isEmpty) return;

    final Set<String> moduleNos = <String>{};
    for (final module in modules) {
      final moduleNo = module.mODULENO?.trim() ?? '';
      if (moduleNo.isEmpty) continue;

      moduleNos.add(moduleNo);

      if (moduleNo.length >= 2) {
        moduleNos.add(moduleNo.substring(moduleNo.length - 2));
      } else {
        moduleNos.add(moduleNo.padLeft(2, '0'));
      }
    }

    _data!.moduleNos = moduleNos.toList();
  }

  /// Restore punch state from today's records.
  /// If day changed and previous state was still open, auto-run punch out online.
  Future<void> _restorePunchStateAndAutoCloseIfNeeded({
    required UserProvider ub,
    required LocationService locService,
    required bool canAutoPunchOut,
    required String logTag,
  }) async {
    if (_data == null) return;

    final userCdStr = ub.syncId ?? '';
    print(
        '$logTag 🔍 Querying punches for userCd="$userCdStr" (from ub.syncId)');
    if (userCdStr.isEmpty) {
      print('$logTag ⚠️ userCdStr is empty, skipping punch restoration');
      return;
    }

    final punches = await locService.getTodaysPunches(userCdStr);
    print('$logTag 📊 Found ${punches.length} punches for today');

    if (punches.isNotEmpty) {
      for (var p in punches) {
        print(
            '$logTag   Punch: ${p['REMARK']} at ${p['VOUCH_TIME']} (USER_CD=${p['USER_CD']})');
      }
      final last = punches.last;
      final remark = (last['REMARK'] ?? '').toString();
      _data!.isPunchIn = remark == 'PUNCH IN';
      print(
          '$logTag ✅ Set isPunchIn=${_data!.isPunchIn} based on last remark="$remark"');
      return;
    }

    print(
        '$logTag ⚠️ No punches found for today, checking previous-day open state');

    final latestPunch = await DatabaseHelper().getLatestPunchForUser(userCdStr);
    final latestRemark = (latestPunch?['REMARK'] ?? '').toString();
    final latestDate = (latestPunch?['VOUCH_DT'] ?? '').toString();

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final hasPreviousDayOpenPunch = latestPunch != null &&
        latestRemark == 'PUNCH IN' &&
        latestDate != todayStr;

    if (!hasPreviousDayOpenPunch) {
      _data!.isPunchIn = false;
      print('$logTag ✅ No previous-day open punch found. Set isPunchIn=false');
      return;
    }

    print(
        '$logTag ⚠️ Found previous-day open punch (date=$latestDate). Need real punch out before showing Punch IN.');

    if (!canAutoPunchOut) {
      _data!.isPunchIn = true;
      print(
          '$logTag ℹ️ Offline mode: cannot auto punch out now. Keeping isPunchIn=true until online.');
      return;
    }

    final syncIdInt = int.tryParse(ub.syncId ?? '0') ?? 0;
    final vouchTime = now.toString().split(' ')[1].split('.').first;

    print('$logTag 🔄 Auto triggering day-change PUNCH OUT...');
    final autoPunchOutResult = await locService.punchOut(
      userCd: userCdStr,
      syncId: syncIdInt,
      token: ub.token ?? '',
      vouchDt: todayStr,
      vouchTime: vouchTime,
      moduleNo: '301',
      remark: 'PUNCH OUT',
    );

    if (autoPunchOutResult['success'] == true) {
      _data!.isPunchIn = false;
      print('$logTag ✅ Day-change auto PUNCH OUT success. Set isPunchIn=false');
    } else {
      _data!.isPunchIn = true;
      print(
          '$logTag ❌ Day-change auto PUNCH OUT failed: ${autoPunchOutResult['message'] ?? autoPunchOutResult['error']}');
      print('$logTag Keeping isPunchIn=true so user can retry punch out.');
    }
  }

  /// Trigger async sync of pending order trackings (START/END order records)
  /// Called on app startup when online and pending trackings exist
  Future<void> _triggerOrderTrackingSync(String token) async {
    try {
      // Import SyncService for syncing pending trackings
      final SyncService syncService = SyncService();
      // Run sync in background without blocking UI
      syncService.syncOrderTrackings(token).then((_) {
        print('[PROFILE-ONLINE] ✅ Order tracking sync completed in background');
      }).catchError((e) {
        print('[PROFILE-ONLINE] ⚠️ Order tracking sync failed: $e');
      });
    } catch (e) {
      print('[PROFILE-ONLINE] ❌ Error triggering order tracking sync: $e');
    }
  }

  @override
  disposeValues() {
    _data = null;
    notifyListeners();
  }
}
