import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/services/background_location_service.dart';
import 'package:arham_corporation/services/location_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../helper/network_helper.dart';
import '../models/profileModal.dart';
import '../models/settingmodal.dart';
import '../services/crashlytics_service.dart';
import '../services/database_helper.dart';
import '../services/services.dart';
import '../services/sync_service.dart';
import '../views/loginpage.dart';

class ProfileProvider extends DisposableProvider {
  DataProfile? _data;

  DataProfile? get data => _data;

  /// Flag to track if profile data has been loaded from API/cache
  bool _isProfileLoaded = false;
  bool get isProfileLoaded => _isProfileLoaded;

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

  int? _lastResumedTripId;
  DateTime? _lastResumedTripAt;

  bool _shouldSkipDuplicateResume(int tripId) {
    final now = DateTime.now();
    if (_lastResumedTripId == tripId &&
        _lastResumedTripAt != null &&
        now.difference(_lastResumedTripAt!).inSeconds < 20) {
      return true;
    }
    _lastResumedTripId = tripId;
    _lastResumedTripAt = now;
    return false;
  }

  Future<bool> _isDeferredAutoPunchOutPending() async {
    try {
      return await BackgroundLocationService().hasPendingAutoPunchOut();
    } catch (e) {
      print(
          '[PROFILE-ONLINE] ⚠️ Failed to read deferred auto punch-out state: $e');
      return false;
    }
  }

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

  Future getProfile({id}) async {
    // NOTE: Do NOT clear _data, YN, ACC_NAME, ACC_CD or call notifyListeners()
    // before the network response. Doing so causes the UI to lose all state
    // (punch button disappears, Start/End Order breaks, partyCd becomes empty).
    // These values will be overwritten once the response arrives.

    // Get auth data from SharedPreferences (no context dependency)
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? '';
    final syncIdStr = sp.getString('SyncId') ?? '';
    final syncId = int.tryParse(syncIdStr) ?? 0;

    await CrashlyticsService.logAction(
      'profile_api_triggered',
      context: {
        'has_token': token.isNotEmpty,
        'sync_id': syncId,
      },
    );

    final bool online = await NetworkHelper.hasInternet();
    if (!online) {
      // Load cached profile if available
      try {
        final cached = await DatabaseHelper().getCachedProfileJson();
        if (cached != null && cached.isNotEmpty) {
          _data = profileModalFromJson(cached).data;
          _isProfileLoaded = true; // ✅ Mark profile as loaded from cache
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

          await CrashlyticsService.setUserContext(
            userId: (_data?.userCd ?? _userCode ?? '').toString(),
            userName: (_data?.userName ?? _userName ?? '').toString(),
            userEmail: '',
            userPhone: (_data?.mobileno ?? '').toString(),
            userRole: (_data?.userType ?? '').toString(),
          );
          await CrashlyticsService.logAction('profile_loaded_from_cache');

          // Restore punch state from local locations table (today's punches)
          try {
            final locService = LocationService();
            final userCodeFromPrefs = _userCode ?? '';
            await _restorePunchStateAndAutoCloseIfNeeded(
              userCd: userCodeFromPrefs,
              syncIdValue: syncId,
              locService: locService,
              logTag: '[PROFILE-OFFLINE]',
            );
          } catch (e) {
            print('[PROFILE-OFFLINE] ❌ Failed to restore punch state: $e');
          }

          // Restore order session state from local order_tracking table
          try {
            if (syncId > 0) {
              final trackings =
                  await DatabaseHelper().getTodayOrderTrackings(syncId);
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
                  // Set ProfileProvider ACC_Name and ACC_CD for this session
                  this.change(partyName, accCd);
                  print(
                      '[PROFILE-OFFLINE] ✅ Restored active order session: party=$accCd, name="$partyName"');
                } else if (trackingType == '3' && remark == 'OUT') {
                  // Order ended - clear party info
                  this.change('', '');
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
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "profile");
      print("Bearer $token");
      print(response.body);

      if (response.statusCode == 200) {
        _data = profileModalFromJson(response.body).data;
        _isProfileLoaded = true; // ✅ Mark profile as loaded

        // Keep module access firm-specific after firm switch.
        await _applyFirmModuleFilter(syncId);

        // Cache profile for offline
        try {
          await DatabaseHelper().cacheProfileJson(response.body);
        } catch (e) {
          print('Failed to cache profile: $e');
        }

        saveUserCode(_data!.userCd.toString());
        saveUserName(_data!.userName.toString());
        print('Profile Data :' + response.body);

        await CrashlyticsService.setUserContext(
          userId: (_data?.userCd ?? '').toString(),
          userName: (_data?.userName ?? '').toString(),
          userEmail: '',
          userPhone: (_data?.mobileno ?? '').toString(),
          userRole: (_data?.userType ?? '').toString(),
        );
        await CrashlyticsService.logAction('profile_loaded_from_api');

        getUserCode();
        getUserName();

        YN = (data?.profileSettings
                    .any((e) => e.variable == 'punchInOut' && e.value == 'Y') ??
                false)
            ? 'Y'
            : 'N';

        getUserCode();
        getUserName();

        // Reconcile punch state with local-first strategy:
        // 1) If today's local punches exist, trust them (they represent this device session)
        // 2) Otherwise use server /orders-tracking remark
        // 3) If server unavailable, fall back to legacy local restoration flow
        String? serverPunchRemark;
        final locService = LocationService();
        final effectiveUserCd =
            (_data?.userCd?.toString().trim().isNotEmpty ?? false)
                ? _data!.userCd.toString().trim()
                : (_userCode ?? '').trim();

        try {
          Future<void> applyPunchInFollowUps() async {
            if (_data?.isPunchIn != true) {
              return;
            }

            final deferredAutoPunchOutPending =
                await _isDeferredAutoPunchOutPending();
            if (deferredAutoPunchOutPending) {
              _data!.isPunchIn = false;
              print(
                  '[PROFILE-ONLINE] ℹ️ Deferred auto punch-out is pending sync. Set isPunchIn=false and skipped trip resume.');
              return;
            }

            try {
              print(
                  '[PROFILE-ONLINE] 🔍 Checking for active trip on server...');
              final activeTrip = await Services()
                  .getActiveTripStatus(effectiveUserCd, syncId, token);

              if (activeTrip != null) {
                final tripId = activeTrip['trip_id'] is int
                    ? activeTrip['trip_id'] as int
                    : int.tryParse(activeTrip['trip_id']?.toString() ?? '');
                if (tripId == null) {
                  print(
                      '[PROFILE-ONLINE] ⚠️ Active trip found but trip_id is invalid: ${activeTrip['trip_id']}');
                } else if (_shouldSkipDuplicateResume(tripId)) {
                  print(
                      '[PROFILE-ONLINE] ℹ️ Duplicate resume skipped for trip_id=$tripId');
                } else {
                  print(
                      '[PROFILE-ONLINE] ✅ Found active trip ($tripId) - RESUMING');
                  await locService.resumeExistingTrip(
                    tripId: tripId,
                    userCd: effectiveUserCd,
                    syncId: syncId,
                    token: token,
                  );
                }
              } else {
                print('[PROFILE-ONLINE] ℹ️ No active trip found on server');
              }
            } catch (e) {
              print(
                  '[PROFILE-ONLINE] ⚠️ Could not check/resume active trip: $e');
            }
          }

          if (effectiveUserCd.isNotEmpty) {
            final localTodayPunches =
                await locService.getTodaysPunches(effectiveUserCd);
            print(
                '[PROFILE-ONLINE] 📊 Local today punches for USER_CD=$effectiveUserCd: ${localTodayPunches.length}');

            if (localTodayPunches.isNotEmpty) {
              final lastLocal = localTodayPunches.last;
              final localRemark = (lastLocal['REMARK'] ?? '').toString();
              _data!.isPunchIn = localRemark == 'PUNCH IN';
              print(
                  '[PROFILE-ONLINE] ✅ Applied LOCAL punch state: remark=$localRemark, isPunchIn=${_data!.isPunchIn}');
              await applyPunchInFollowUps();
            } else {
              print(
                  '[PROFILE-ONLINE] ℹ️ No local today punches found, checking local previous-day open state...');
              await _restorePunchStateAndAutoCloseIfNeeded(
                userCd: effectiveUserCd,
                syncIdValue: syncId,
                locService: locService,
                logTag: '[PROFILE-ONLINE]',
              );

              if (!_data!.isPunchIn) {
                print(
                    '[PROFILE-ONLINE] ℹ️ No local open punch found, checking server state...');
                serverPunchRemark =
                    await Services().getCurrentPunchState(token);
                print(
                    '[PROFILE-ONLINE] 📊 Server punch state: $serverPunchRemark');

                if (serverPunchRemark != null && serverPunchRemark.isNotEmpty) {
                  _data!.isPunchIn = serverPunchRemark == 'PUNCH IN';
                  print(
                      '[PROFILE-ONLINE] ✅ Applied SERVER punch state directly: isPunchIn=${_data!.isPunchIn}');
                }
              } else {
                print(
                    '[PROFILE-ONLINE] ✅ Preserved punched-in state from previous-day local record.');
              }

              await applyPunchInFollowUps();
            }
          } else {
            print(
                '[PROFILE-ONLINE] ⚠️ effectiveUserCd is empty, falling back to legacy restoration flow');
            await _restorePunchStateAndAutoCloseIfNeeded(
              userCd: effectiveUserCd,
              syncIdValue: syncId,
              locService: locService,
              logTag: '[PROFILE-ONLINE]',
            );
          }
        } catch (e) {
          print('[PROFILE-ONLINE] ❌ Punch state reconciliation failed: $e');
        }

        // Restore order session state from local order_tracking table
        try {
          final syncIdInt = syncId;
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
                // Set ProfileProvider ACC_Name and ACC_CD for this session
                this.change(partyName, accCd);
                print(
                    '[PROFILE-ONLINE] ✅ Restored active order session: party=$accCd, name="$partyName"');
              } else if (trackingType == '3' && remark == 'OUT') {
                // Order ended - clear party info
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
          if (pendingTrackings.isNotEmpty && token.isNotEmpty) {
            print(
                '[PROFILE-ONLINE] 🔄 Found ${pendingTrackings.length} pending order tracking(s) — triggering sync');
            // Import and call sync service to push pending trackings
            _triggerOrderTrackingSync(token);
          }
        } catch (e) {
          print(
              '[PROFILE-ONLINE] ⚠️ Failed to trigger order tracking sync: $e');
        }

        notifyListeners();
      } else {
        // Redirect to login if profile fetch failed
        print("Profile fetch failed - redirecting to login");
        Get.offAll(() => LoginPage());
      }
    } catch (e, stack) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in ProfileProvider getProfile  ${e.toString()}");
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'profile_fetch_failed',
      );
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

      // ⚡⚡⚡ OPTIMISTIC LOADING: Try API immediately without internet check!
      // This saves ~2 seconds that was spent on connectivity check
      print('[SETTINGS] Loading settings from API (optimistic)');
      try {
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
                '[SETTINGS] ✅ Cached ${settingsMaps.length} settings for offline');
          } catch (e) {
            print('[SETTINGS] Failed to cache settings: $e');
          }
          print(
              '[SETTINGS] ✅ Loaded ${settingResponse.data.length} settings from API');
        } else {
          print(
              '[SETTINGS] No settings data received from API, trying cache...');
          // Fall back to cache if API returns empty
          await _loadSettingsFromCache();
        }
      } catch (e) {
        // ❌ API FAILED - fallback to cache
        print('[SETTINGS] 🔴 API failed: $e, falling back to cache');
        await _loadSettingsFromCache();
      }

      notifyListeners();
    } catch (e) {
      print('[SETTINGS] Error in loadSettings: $e');
    }
  }

  /// Helper method to load settings from local cache
  Future<void> _loadSettingsFromCache() async {
    try {
      print('[SETTINGS] Loading settings from local cache (offline)');
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
            '[SETTINGS] ✅ Loaded ${settingsList.length} settings from cache (merged)');
      } else {
        print('[SETTINGS] No cached settings available');
      }
    } catch (e) {
      print('[SETTINGS] Failed to load cached settings: $e');
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

  /// Check if offline mode is enabled in settings for the CURRENT FIRM (sync ID)
  /// Settings are loaded per-firm, so this check is firm-specific
  /// Example:
  ///   - Firm 1234 (syncId=1234): enableOfflineMode='Y' → returns TRUE
  ///   - Firm 1235 (syncId=1235): enableOfflineMode='N' → returns FALSE
  /// Returns true if enableOfflineMode setting value is 'Y' for current firm
  bool isOfflineModeEnabled() {
    if (_data == null) {
      print(
          '[PROFILE] ⚠️ Profile data is NULL - profile not yet loaded (offline mode disabled by default)');
      return false; // Default to disabled if profile not loaded
    }

    if (_data?.profileSettings == null || _data!.profileSettings.isEmpty) {
      print(
          '[PROFILE] ⚠️ Profile settings is NULL/EMPTY - offline mode disabled by default');
      return false; // Default to disabled if no settings
    }

    print('[PROFILE] Total settings loaded: ${_data!.profileSettings.length}');
    // --Print setting names in logs--
    // for (var setting in _data!.profileSettings) {
    //   print(
    //       '[PROFILE] Setting: variable=${setting.variable}, value=${setting.value}');
    // }

    try {
      // Find the offline mode setting
      for (var setting in _data!.profileSettings) {
        if (setting.variable == 'enableOfflineMode') {
          final isEnabled = setting.value?.toString().toUpperCase() == 'Y';
          print(
              '[PROFILE] 🔍 Found enableOfflineMode: value=${setting.value} → $isEnabled');
          return isEnabled;
        }
      }
      // Setting not found
      print(
          '[PROFILE] ⚠️ enableOfflineMode setting NOT found - defaulting to disabled');
      return false;
    } catch (e) {
      print('[PROFILE] ❌ Error checking offline mode setting: $e');
      return false;
    }
  }

  bool isWhatsAppShareOnOrderEnabled() {
    if (_data == null) {
      print(
          '[PROFILE] ⚠️ Profile data is NULL - WhatsApp share on order disabled by default');
      return false;
    }

    if (_data?.profileSettings == null || _data!.profileSettings.isEmpty) {
      print(
          '[PROFILE] ⚠️ Profile settings is NULL/EMPTY - WhatsApp share on order disabled by default');
      return false;
    }

    try {
      for (var setting in _data!.profileSettings) {
        if (setting.variable == 'askWhatsAppShareOnOrder') {
          final isEnabled = setting.value?.toString().toUpperCase() == 'Y';
          print(
              '[PROFILE] 🔍 Found askWhatsAppShareOnOrder: value=${setting.value} → $isEnabled');
          return isEnabled;
        }
      }

      print(
          '[PROFILE] ⚠️ askWhatsAppShareOnOrder setting NOT found - defaulting to disabled');
      return false;
    } catch (e) {
      print('[PROFILE] ❌ Error checking askWhatsAppShareOnOrder setting: $e');
      return false;
    }
  }

  Future<void> _applyFirmModuleFilter(int syncId) async {
    _ensureLegacyModuleNosFromModulesList();

    // Get token from SharedPreferences
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token')?.trim() ?? '';

    if (syncId <= 0) {
      print(
          '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: syncId is empty/invalid');
      return;
    }

    if (token.isEmpty) {
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
            (firm['SYNC_ID']?.toString().trim() ?? '') == syncId.toString()) {
          selectedFirm = firm;
          break;
        }
      }

      if (selectedFirm == null) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: selected firm ${syncId.toString()} not found in /firm');
        return;
      }

      print(
          '[PROFILE-ONLINE] Selected firm raw for syncId=${syncId.toString()} => $selectedFirm');

      final moduleNosRaw = selectedFirm['MODULE_NOS']?.toString().trim() ?? '';
      if (moduleNosRaw.isEmpty) {
        print(
            '[PROFILE-ONLINE] ⚠️ Firm module filter skipped: MODULE_NOS empty for syncId=${syncId.toString()}');
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
          '[PROFILE-ONLINE] ✅ Applied firm module filter for syncId=${syncId.toString()} (before=$before, after=$after)');
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

  /// Restore punch state from local records.
  /// If there is a previous-day open punch (last record is PUNCH IN), keep
  /// punched-in state until an explicit punch out is recorded.
  Future<void> _restorePunchStateAndAutoCloseIfNeeded({
    required String userCd,
    required int syncIdValue,
    required LocationService locService,
    required String logTag,
  }) async {
    if (_data == null) return;

    print('$logTag [SYNC-ID] syncIdValue=$syncIdValue');
    print(
        '$logTag [USER-CD] _data.userCd="${_data?.userCd}" | _userCode="$_userCode"');

    // Prefer _userCode if available, otherwise use userCd parameter
    final actualUserCd = _userCode ?? userCd;
    print('$logTag 🔍 Querying punches for userCd="$actualUserCd"');

    if (actualUserCd.isEmpty) {
      print('$logTag ⚠️ userCd is empty, skipping punch restoration');
      return;
    }

    final punches = await locService.getTodaysPunches(actualUserCd);
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

    final latestPunch =
        await DatabaseHelper().getLatestPunchForUser(actualUserCd);
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
        '$logTag ⚠️ Found previous-day open punch (date=$latestDate). Preserving punched-in state across day change.');
    _data!.isPunchIn = true;
    print('$logTag ✅ Set isPunchIn=true from previous-day open punch.');
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
