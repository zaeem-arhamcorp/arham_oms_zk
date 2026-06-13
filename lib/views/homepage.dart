import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/helper/notification_services.dart';
import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/models/dashboardmodal.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/controller/product_controller.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/battery_optimization_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/location_permission_service.dart';
import 'package:arham_corporation/views/monthly_target/models/monthly_target_item_model.dart';
import 'package:arham_corporation/views/orderReportScreen.dart';
import 'package:arham_corporation/views/route_schedule_plan/controllers/beat_controller.dart';
import 'package:arham_corporation/widgets/battery_optimization_dialog.dart';
import 'package:arham_corporation/widgets/common_app_drawer.dart';
import 'package:arham_corporation/widgets/location_permission_dialog.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whatsapp_share/whatsapp_share.dart';

import '../providers/item_list_provider.dart';
import '../services/authservices.dart';
import '../services/offline_caching_service.dart'
    show OfflineCachingService, CacheItemStatus;
import '../services/services.dart';
import '../services/sync_service.dart';
import '../widgets/bottomnavebar.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const MethodChannel _manufacturerChannel = MethodChannel('my_channel');
  DashboardModal? data;
  bool nolist = false;
  bool _isOrderShareDialogVisible = false;
  String? _queuedSecondarySharePhone;
  String? _queuedSecondaryShareFilePath;
  String _queuedSecondaryShareLabel = 'stockist';
  bool _isHandlingQueuedSecondaryShare = false;
  late ProfileProvider
      _profileProvider; // Store provider reference to avoid accessing during dispose

  Future<void> getDashboarddata() async {
    if (!mounted) return;

    setState(() {
      data = null;
      nolist = false;
    });

    // ✅ OPTIMIZED: Call API immediately without network check
    // Network check was blocking the dashboard API - removed!
    // If offline, the API call will fail gracefully and we load from cache

    // ✅ Guard: Check if widget is still mounted before calling API
    if (!mounted) return;

    BuildContext currentContext;
    try {
      currentContext = context;
    } catch (e) {
      // State may already be detached; silently skip refresh.
      return;
    }

    Services().getDashboarddata(currentContext).then((value) async {
      // ✅ Guard: Check mounted again after async operation
      if (!mounted) return;

      if (value != null) {
        setState(() {
          data = value;
          if (data!.data.labelData.transaction.isEmpty) {
            nolist = true;
          }
        });

        // Cache dashboard data for offline use (always cache valid data)
        try {
          await DatabaseHelper().cacheHomeData(
            'dashboard',
            dashboardModalToJson(value),
          );
          print("Dashboard cached successfully");
        } catch (e) {
          print("Error caching dashboard data: $e");
        }
      } else {
        // API returned null - load from cache instead
        try {
          final cached = await DatabaseHelper().getCachedHomeData('dashboard');
          if (cached != null && cached.isNotEmpty && cached != 'null') {
            final cachedData = dashboardModalFromJson(cached);
            if (!mounted) return; // Guard before setState
            setState(() {
              data = cachedData;
              if (data!.data.labelData.transaction.isEmpty) {
                nolist = true;
              }
            });
          } else {
            if (!mounted) return; // Guard before setState
            setState(() {
              nolist = true;
            });
          }
        } catch (e) {
          print("Error loading cached dashboard: $e");
          if (!mounted) return; // Guard before setState
          setState(() {
            nolist = true;
          });
        }
      }
    }).catchError((e) {
      // API call failed (likely offline) - load from cache
      print("Dashboard API failed: $e - loading from cache");
      DatabaseHelper().getCachedHomeData('dashboard').then((cached) {
        if (!mounted) return; // Guard before accessing state
        if (cached != null && cached.isNotEmpty && cached != 'null') {
          try {
            final cachedData = dashboardModalFromJson(cached);
            if (!mounted) return; // Guard before setState
            setState(() {
              data = cachedData;
              if (data!.data.labelData.transaction.isEmpty) {
                nolist = true;
              }
            });
          } catch (e) {
            print("Error parsing cached dashboard: $e");
            if (!mounted) return; // Guard before setState
            setState(() {
              nolist = true;
            });
          }
        } else {
          if (!mounted) return; // Guard before setState
          setState(() {
            nolist = true;
          });
        }
      });
    });
  }

  List<Map<String, dynamic>> firmList = [];
  int? selectedSyncId; // Stores the selected sync ID
  String? selectedFirmName; // Stores the selected firm name
  String? selectedFirmLogo; // Stores selected firm's logo URL
  bool isLoading = true;

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;
  late Future<MonthlyTargetItemModel?> _monthlyTargetFuture;

  Future<MonthlyTargetItemModel?> _fetchCurrentMonthPobTarget() async {
    if (_profileProvider.data != null &&
        _profileProvider.data!.modulesList!.any(
            (module) => module.mODULENO == "236" && module.rEADRIGHT == true)) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final token = userProvider.token;
        String? userCd = _profileProvider.data?.userCd?.toString();
        if (token == null || token.trim().isEmpty) {
          print('[HomePage] Monthly target fetch skipped: missing token');
          return null;
        }

        final targetMonth = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final uri = Uri.parse(
          '${AppConfig.baseURL}monthly-sales-target?&userCd=$userCd&targetMonth=$targetMonth&type=POB',
        );

        print('[HomePage] Fetching monthly target: $uri');
        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
          },
        );

        print('[HomePage] Monthly target response: ${response.statusCode}');
        if (response.statusCode != 200 && response.statusCode != 201) {
          return null;
        }

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        if (data is! List || data.isEmpty) {
          return null;
        }

        final now = DateTime.now();
        MonthlyTargetItemModel? monthItem;

        for (final item in data.whereType<Map>()) {
          final model = MonthlyTargetItemModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (model.type.toUpperCase() != 'POB') continue;

          final parsedTargetDate = DateTime.tryParse(model.targetDate);
          if (parsedTargetDate != null &&
              parsedTargetDate.year == now.year &&
              parsedTargetDate.month == now.month) {
            monthItem = model;
            break;
          }

          final monthNames = [
            'january',
            'february',
            'march',
            'april',
            'may',
            'june',
            'july',
            'august',
            'september',
            'october',
            'november',
            'december'
          ];
          final expectedMonth = '${now.year}-${monthNames[now.month - 1]}';
          if (model.targetMonth.toLowerCase() == expectedMonth) {
            monthItem = model;
            break;
          }
        }

        return monthItem;
      } catch (e) {
        print('[HomePage] Monthly target fetch error: $e');
        return null;
      }
    } else {
      print(
          '[HomePage] Monthly target fetching skipped: moduleNo 236 not found');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CrashlyticsService.setScreenName('HomePage');
    CrashlyticsService.logAction('home_screen_opened');

    // Mark HomePage active for conditional snack bar behavior
    Global.isHomeActive = true;

    getDashboarddata();
    notification();
    loadData();
    _fetchActiveTripStatus();
    // Future.microtask(() {
    //   notification();
    //   loadData();
    // });

    _profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _monthlyTargetFuture = _fetchCurrentMonthPobTarget();

    // Load today's beat schedule for current user (if available)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final beatCtrl = Get.isRegistered<BeatController>()
            ? Get.find<BeatController>()
            : Get.put(BeatController());

        String? userCd = _profileProvider.data?.userCd?.toString();
        if (userCd == null || userCd.isEmpty) {
          final sp = await SharedPreferences.getInstance();
          userCd = sp.getString('UserCode') ?? '';
        }

        if (userCd != null && userCd.isNotEmpty) {
          await beatCtrl.fetchUserBeatSchedule(userCd);
          if (mounted) setState(() {});
        }
      } catch (e) {
        print('[HomePage] Failed to load beat schedule: $e');
      }
    });

    // Add listener to show warning snackbar whenever it's set by the API
    _profileProvider.addListener(_handlePendingWarning);

    // Add listener to show stale-trip punch-out prompt after HomePage is ready
    _profileProvider.addListener(_handlePendingStaleTripPunchOut);

    // Check for any existing warning at init time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingWarning();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingStaleTripPunchOut();
    });

    // Show post-order WhatsApp share popup on homepage (if pending payload exists)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndShowPendingOrderSharePopup();
    });

    // Auto-cache data on first login or firm switch (checked via SharedPreferences)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return; // Guard: exit if widget disposed
      final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
      if (ub.token != null && ub.syncId != null) {
        if (!mounted) return; // Guard again after async
        final ProfileProvider pb =
            Provider.of<ProfileProvider>(context, listen: false);

        // ✅ Check if offline mode is enabled in settings
        final isOfflineModeEnabled = _isOfflineModeEnabled(pb);
        print('[HomePage] Offline mode enabled: $isOfflineModeEnabled');

        if (!isOfflineModeEnabled) {
          print('[HomePage] Offline mode is disabled - skipping auto-cache');
          return;
        }

        final syncId = ub.syncId!;
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'auto_cached_firm_$syncId';
        final flagExists = prefs.containsKey(cacheKey);

        print(
            '[HomePage] Auto-cache check: syncId=$syncId, cacheKey=$cacheKey, flagExists=$flagExists');

        // Check if already cached for this firm
        if (!flagExists) {
          print('[HomePage] Triggering auto-cache for firm $syncId');
          _showAutoOfflineCachingDialog(syncId);
        } else {
          print('[HomePage] Auto-cache already done for firm $syncId');
          // Still show battery dialog even if caching was already done
          await Future.delayed(Duration(milliseconds: 1500));
          if (!mounted) return; // Guard before checking punchInOut
          final isPunchEnabled = _isPunchInOutEnabled();
          if (isPunchEnabled) {
            _checkAndShowBatteryOptimizationDialog();
          } else {
            print(
                '[HomePage] punchInOut is disabled - skipping battery and location dialogs');
          }
        }
      } else {
        print(
            '[HomePage] Auto-cache check skipped: token=${ub.token}, syncId=${ub.syncId}');
      }
    });
//punchInOut
    // Sync license info on dashboard initialization
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return; // Guard: exit if widget disposed
      final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
      if (ub.token != null && ub.syncId != null) {
        final syncId = int.tryParse(ub.syncId ?? '0') ?? 0;

        // Get CUST_ID for license-info endpoint
        await ub.getCustId();
        final custId = ub.custId;

        // Call syncOrders to sync any pending orders and get license info
        final result =
            await SyncService().syncOrders(ub.token!, syncId: syncId);
        print(
            '[HomePage] Sync result: synced=${result['synced']}, failed=${result['failed']}');

        // Check for renewal and retry rejected orders
        if (mounted) {
          try {
            final licenseInfo = await DatabaseHelper().getLicenseInfo(syncId);
            if (licenseInfo != null) {
              final isBlacklisted =
                  ((licenseInfo['autoBlacklisted'] as int?) ?? 0) == 1;
              final renewalTriggered = licenseInfo['renewalTriggered'] == 1;

              if (renewalTriggered) {
                print(
                    '[HomePage] License renewal detected - retrying rejected orders');
                await SyncService()
                    .retryRejectedOrders(ub.token!, syncId: syncId);
              }

              // If still blacklisted but no pending orders synced, get fresh license info
              // This handles the case where admin extended the limit but we didn't sync any orders
              if (isBlacklisted && result['synced'] == 0) {
                print(
                    '[HomePage] ⚠️ Still blacklisted but no orders synced - fetching fresh license info');
                await _fetchFreshLicenseInfoForBlacklist(ub.token!, syncId);
              }
            }

            // Also fetch license info from dedicated license-info endpoint if CUST_ID is available
            if (custId != null && custId.isNotEmpty) {
              print(
                  '[HomePage] 📊 Fetching license info from license-info endpoint...');
              await _fetchLicenseInfoFromLicenseInfoEndpoint(
                  ub.token!, syncId, custId);
            }
          } catch (e) {
            print('[HomePage] Error checking license status: $e');
          }
        }
      }
    });

    final ProfileProvider p = _profileProvider;
    _monthlyTargetFuture = _fetchCurrentMonthPobTarget();

    var narrationEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "109",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (narrationEntryModule.mODULENO == "109") {
      narrationModuleNo = narrationEntryModule.mODULENO!;
      narrationReadRight = narrationEntryModule.rEADRIGHT!;
      narrationWriteRights = narrationEntryModule.wRITERIGHT!;
      narrationUpdateRights = narrationEntryModule.uPDATERIGHT!;
      narrationDeleteRight = narrationEntryModule.dELETERIGHT!;
      narrationPrintRights = narrationEntryModule.pRINTRIGHT!;
    } else {
      print("Module with mODULENO '109' not found.");
    }
  }

  void _queueSecondaryShare({
    required String phone,
    required String filePath,
    required String label,
  }) {
    _queuedSecondarySharePhone = phone;
    _queuedSecondaryShareFilePath = filePath;
    _queuedSecondaryShareLabel = label;
  }

  Future<void> _triggerQueuedSecondaryShareIfAny() async {
    if (!mounted || _isHandlingQueuedSecondaryShare) return;

    final phone = _queuedSecondarySharePhone;
    final filePath = _queuedSecondaryShareFilePath;
    final label = _queuedSecondaryShareLabel;

    if (phone == null || filePath == null) return;

    _isHandlingQueuedSecondaryShare = true;
    _queuedSecondarySharePhone = null;
    _queuedSecondaryShareFilePath = null;

    try {
      final shared = await _sharePdfToRecipient(
        phone: phone,
        filePath: filePath,
      );

      if (shared) {
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Opened WhatsApp share for $label',
          backgroundColor: Colors.green,
        );
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message: 'Could not open WhatsApp share for $label',
        );
      }
    } finally {
      _isHandlingQueuedSecondaryShare = false;
    }
  }

  Future<void> _fetchActiveTripStatus() async {
    if (!mounted) return;

    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);

    if (profile.userCode == null || user.token == null) return;

    final syncId = int.tryParse(user.syncId?.toString() ?? '0') ?? 0;

    try {
      final activeTrip = await Services()
          .getActiveTripStatus(profile.userCode!, syncId, user.token!);

      if (!mounted) return;

      if (activeTrip != null) {
        // SUCCESS: You found an active trip.
        // Update the UI here, for example:
        print("Active trip found: ${activeTrip['trip_id']}");
      } else {
        print("No active trip at this moment.");
      }
    } catch (e) {
      print('Error during API call: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerQueuedSecondaryShareIfAny();
      _fetchActiveTripStatus();
    }
  }

  Future<String> getManufacturer() async {
    if (!Platform.isAndroid) return 'unknown';

    try {
      final manufacturer =
          await _manufacturerChannel.invokeMethod<String>('getManufacturer');
      return (manufacturer ?? 'unknown').toLowerCase();
    } on PlatformException catch (e) {
      print('[HomePage] Failed to get manufacturer: ${e.message}');
      return 'unknown';
    } catch (e) {
      print('[HomePage] Unexpected error while getting manufacturer: $e');
      return 'unknown';
    }
  }

  String getInstructionForDevice(String manufacturer) {
    if (manufacturer.contains('vivo')) {
      return "1. Open Settings -> Apps\n2. Go to 'Special app access'\n3. Open 'Background power consumption management'\n4. Select ArhamOMS\n5. Click on Don't restrict.";
    }

    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
      return 'Enable Auto-start for this app, set Battery saver to No restrictions, and lock the app in Recents.';
    }

    if (manufacturer.contains('oppo') || manufacturer.contains('realme')) {
      return 'Open App management and allow background activity for this app.';
    }

    // if (manufacturer.contains('samsung')) {
    //   return 'Open Battery settings and disable battery optimization for this app.';
    // }

    return 'Please make sure that if any battery optimization or background power consumption restrictions are enabled for this app anywhere in your device settings, kindly disable them to ensure reliable tracking.';
  }

  Future<void> showBatteryGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownBatteryGuide = prefs.getBool('hasShownBatteryGuide') ?? false;

    if (hasShownBatteryGuide || !mounted) return;

    final manufacturer = await getManufacturer();
    final instruction = getInstructionForDevice(manufacturer);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.battery_charging_full_sharp,
              color: Colors.orange,
              size: 28,
            ),
            SizedBox(
              width: 12,
            ),
            Text(
              'One Last Check',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        content: Text(instruction),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: Text('OK'),
          ),
        ],
      ),
    );

    await prefs.setBool('hasShownBatteryGuide', true);
  }

  /// Handles showing the pending warning snackbar when it's set by the API.
  /// This listener is called whenever ProfileProvider notifies listeners of changes.
  void _handlePendingWarning() {
    // Safety check: ensure widget is still mounted before accessing provider
    if (!mounted) return;

    if (_profileProvider.pendingWarning != null &&
        _profileProvider.pendingWarning!.isNotEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
        message: _profileProvider.pendingWarning!,
        backgroundColor: Colors.orange,
      );
      _profileProvider.clearPendingWarning();
    }
  }

  bool _isOfflineModeEnabled(ProfileProvider profileProvider) {
    final settings = profileProvider.data?.profileSettings;
    if (settings == null || settings.isEmpty) {
      return false;
    }

    for (final setting in settings) {
      if (setting.variable == 'enableOfflineMode') {
        return setting.value?.toString().toUpperCase() == 'Y';
      }
    }

    return false;
  }

  bool _isWhatsAppShareOnOrderEnabled(ProfileProvider profileProvider) {
    final settings = profileProvider.data?.profileSettings;
    if (settings == null || settings.isEmpty) {
      return false;
    }

    for (final setting in settings) {
      if (setting.variable == 'askWhatsAppShareOnOrder') {
        return setting.value?.toString().toUpperCase() == 'Y';
      }
    }

    return false;
  }

  Future<void> _handlePendingStaleTripPunchOut() async {
    if (!mounted) return;
    if (!_profileProvider.pendingStaleTripPunchOut) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final location = Provider.of<LocationProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    await Get.dialog(
      CupertinoAlertDialog(
        title: const Text('Punch Out required'),
        content: const Text(
          'Your active trip should have been punched out before 11:00 PM. Please punch out now.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text(
              'Punch Out',
              style: TextStyle(color: Colors.red),
            ),
            // onPressed: () async {
            //   location.setRemarks('PUNCH OUT');
            //   final punchSucceeded = await location.sendLocation(userProvider,
            //       profile: profileProvider);
            //
            //   if (!mounted) {
            //     return;
            //   }
            //
            //   if (punchSucceeded) {
            //     _profileProvider.clearPendingStaleTripPunchOut();
            //     if (Get.isDialogOpen == true) {
            //       Get.back();
            //     }
            //   } else {
            //     AppSnackBar.showGetXCustomSnackBar(
            //       message:
            //           'Punch out failed. Please connect to the internet and try again.',
            //       backgroundColor: Colors.red,
            //     );
            //   }
            // },
            onPressed: () async {
              location.setRemarks('PUNCH OUT');

              final punchSucceeded = await location.sendLocation(
                userProvider,
                profile: profileProvider,
              );

              if (!mounted) return;

              if (!punchSucceeded) {
                AppSnackBar.showGetXCustomSnackBar(
                  message:
                      'Punch out failed. Please connect to the internet and try again.',
                  backgroundColor: Colors.red,
                );
                return;
              }

              _profileProvider.clearPendingStaleTripPunchOut();

              print('Pending Punch Out Dialog Before Get.back');
              Get.back(result: true);
              print('Pending Punch Out Dialog After Get.back');
            },
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<String?> _downloadOrderReportPdfForShare(String reportUrl) async {
    final reportName =
        'Order_Report_${DateFormat('dd-MM-yyyy_HH-mm-ss').format(DateTime.now())}';

    if (Platform.isIOS) {
      return Helper.saveFileIOS(
        reportUrl,
        reportName,
        'PDF downloaded for sharing',
      );
    }

    return Helper.saveFileAndroid(
      reportUrl,
      reportName,
      'PDF downloaded for sharing',
    );
  }

  Future<bool> _sharePdfToRecipient({
    required String phone,
    required String filePath,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty) return false;

    try {
      await WhatsappShare.shareFile(
        phone: normalizedPhone,
        filePath: [filePath],
        package: Package.whatsapp,
      );
      return true;
    } catch (e) {
      print('[HomePage] PDF share failed for $normalizedPhone: $e');
      return false;
    }
  }

  Future<void> _checkAndShowPendingOrderSharePopup() async {
    if (!mounted || _isOrderShareDialogVisible) return;

    if (!_isWhatsAppShareOnOrderEnabled(_profileProvider)) {
      print('[HomePage] WhatsApp share on order disabled - skipping popup');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final syncId = (userProvider.syncId ?? '').trim();
    final payloadKey = syncId.isNotEmpty
        ? 'whatsapp_share_dialog_payload_$syncId'
        : 'whatsapp_share_dialog_payload';
    final legacyFirmPayloadKey = syncId.isNotEmpty
        ? 'pending_order_share_payload_$syncId'
        : 'pending_order_share_payload';
    const legacyGlobalPayloadKey = 'pending_order_share_payload';

    final prefs = await SharedPreferences.getInstance();
    final shouldShowMilestone =
        prefs.getBool('show_5000_orders_congrats') ?? false;
    final milestoneOrderAmount =
        prefs.getDouble('milestone_order_amount') ?? 5000;
    String? payloadString = prefs.getString(payloadKey);
    if (payloadString == null || payloadString.trim().isEmpty) {
      payloadString = prefs.getString(legacyFirmPayloadKey);
    }
    if (payloadString == null || payloadString.trim().isEmpty) {
      payloadString = prefs.getString(legacyGlobalPayloadKey);
    }
    if (payloadString == null || payloadString.trim().isEmpty) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      print('[HomePage] Invalid pending share payload: $e');
      await prefs.remove(payloadKey);
      await prefs.remove(legacyFirmPayloadKey);
      await prefs.remove(legacyGlobalPayloadKey);
      return;
    }

    final reportUrl = (payload['reportUrl'] ?? '').toString().trim();
    final partyName = (payload['partyName'] ?? 'Party').toString().trim();
    final partyNumber = (payload['partyNumber'] ?? '').toString().trim();
    final partyDisplayNumber =
        (payload['partyDisplayNumber'] ?? '').toString().trim();

    final stockistName = (payload['stockistName'] ?? null).toString().trim();
    final stockistNumber = (payload['stockistNumber'] ?? '').toString().trim();
    final stockistDisplayNumber =
        (payload['stockistDisplayNumber'] ?? '').toString().trim();

    final hasParty = partyNumber.isNotEmpty;
    final hasStockist = stockistNumber.isNotEmpty;

    // Consume payload once so popup appears only once after success redirect
    await prefs.remove(payloadKey);
    await prefs.remove(legacyFirmPayloadKey);
    await prefs.remove(legacyGlobalPayloadKey);

    if (reportUrl.isEmpty || (!hasParty && !hasStockist)) {
      print('[HomePage] Pending share payload has no valid report/recipient');
      return;
    }

    bool shareParty = hasParty;
    bool shareStockist = hasStockist;
    String validationError = '';
    _isOrderShareDialogVisible = true;
    final leftConfettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    final rightConfettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    bool dialogOpen = true;

    try {
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Trigger confetti after a small delay for better UX
              if (shouldShowMilestone) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && dialogOpen) {
                    leftConfettiController.play();
                    rightConfettiController.play();
                  }
                });
              }

              return Stack(
                children: [
                  AlertDialog(
                    title: Row(
                      children: [
                        Image.asset(
                          "assets/whatsapp_icon.png",
                          height: 30,
                        ),
                        const Text('Share Order Report'),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (shouldShowMilestone)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Congratulations! You placed an order of amount ${milestoneOrderAmount.toStringAsFixed(2)}.',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Text(
                          'Share PDF on WhatsApp to:',
                          style: TextStyle(
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: shareParty,
                          onChanged: hasParty
                              ? (val) {
                                  setDialogState(() {
                                    shareParty = val ?? false;
                                    validationError = '';
                                  });
                                }
                              : null,
                          title: Text('Party: $partyName'),
                          subtitle: Text(
                            hasParty
                                ? 'Number: $partyDisplayNumber'
                                : 'No WhatsApp/Phone number available',
                          ),
                        ),
                        if (hasStockist)
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: shareStockist,
                            onChanged: hasStockist
                                ? (val) {
                                    setDialogState(() {
                                      shareStockist = val ?? false;
                                      validationError = '';
                                    });
                                  }
                                : null,
                            title: Text(
                                'Stockist: ${stockistName.isEmpty ? 'N/A' : stockistName}'),
                            subtitle: Text(
                              hasStockist
                                  ? 'Number: $stockistDisplayNumber'
                                  : 'No WhatsApp/Phone number available',
                            ),
                          ),
                        if (validationError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              validationError,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!shareParty && !shareStockist) {
                            setDialogState(() {
                              validationError =
                                  'Please select at least one recipient';
                            });
                            return;
                          }

                          Navigator.of(dialogContext).pop();

                          final filePath =
                              await _downloadOrderReportPdfForShare(reportUrl);
                          if (filePath == null || filePath.trim().isEmpty) {
                            AppSnackBar.showGetXCustomSnackBar(
                              message: 'Unable to download PDF for sharing',
                            );
                            return;
                          }

                          int openedCount = 0;
                          int failedCount = 0;

                          final shareBothSelected = shareParty &&
                              hasParty &&
                              shareStockist &&
                              hasStockist;

                          if (shareBothSelected) {
                            final partyShared = await _sharePdfToRecipient(
                              phone: partyNumber,
                              filePath: filePath,
                            );

                            if (partyShared) {
                              openedCount++;
                              _queueSecondaryShare(
                                phone: stockistNumber,
                                filePath: filePath,
                                label: stockistName.isEmpty
                                    ? 'stockist'
                                    : stockistName,
                              );
                              AppSnackBar.showGetXCustomSnackBar(
                                message:
                                    'Party share opened. Return to app to open stockist share.',
                                backgroundColor: Colors.orange,
                              );
                            } else {
                              failedCount++;
                              final stockistShared = await _sharePdfToRecipient(
                                phone: stockistNumber,
                                filePath: filePath,
                              );
                              if (stockistShared) {
                                openedCount++;
                              } else {
                                failedCount++;
                              }
                            }
                          } else {
                            if (shareParty && hasParty) {
                              final shared = await _sharePdfToRecipient(
                                phone: partyNumber,
                                filePath: filePath,
                              );
                              if (shared) {
                                openedCount++;
                              } else {
                                failedCount++;
                              }
                            }

                            if (shareStockist && hasStockist) {
                              final shared = await _sharePdfToRecipient(
                                phone: stockistNumber,
                                filePath: filePath,
                              );
                              if (shared) {
                                openedCount++;
                              } else {
                                failedCount++;
                              }
                            }
                          }

                          if (openedCount > 0) {
                            AppSnackBar.showGetXCustomSnackBar(
                              message: 'Opening WhatsApp share...',
                              backgroundColor: Colors.green,
                            );
                          }
                          if (failedCount > 0) {
                            AppSnackBar.showGetXCustomSnackBar(
                              message: 'Could not open some WhatsApp links',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              "assets/whatsapp_icon.png",
                              height: 20,
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Text('Share'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Left confetti - fires upward-right at 45 degrees from middle of left edge
                  if (shouldShowMilestone)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConfettiWidget(
                        confettiController: leftConfettiController,
                        blastDirection:
                            -0.7854, // π/4 radians = 45 degrees upward-right
                        maxBlastForce: 30,
                        minBlastForce: 20,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        gravity: 0.1,
                        shouldLoop: false,
                        displayTarget: false,
                      ),
                    ),
                  // Right confetti - fires upward-left at 45 degrees from middle of right edge
                  if (shouldShowMilestone)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConfettiWidget(
                        confettiController: rightConfettiController,
                        blastDirection:
                            -2.356, // 3π/4 radians = 135 degrees upward-left
                        maxBlastForce: 30,
                        minBlastForce: 20,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        gravity: 0.1,
                        shouldLoop: false,
                        displayTarget: false,
                      ),
                    ),
                ],
              );
            },
          );
        },
      );
    } finally {
      dialogOpen = false;
      leftConfettiController.dispose();
      rightConfettiController.dispose();
      if (shouldShowMilestone) {
        await prefs.remove('show_5000_orders_congrats');
        await prefs.remove('milestone_order_amount');
      }
      _isOrderShareDialogVisible = false;
    }
  }

  Future<void> notification() async {
    await NotificationService().requestNotificationPermission();
  }

  /// Fetch fresh license info by making a minimal order request to /api/orders
  /// This is used when user is blacklisted but there are no pending orders to sync
  Future<void> _fetchFreshLicenseInfoForBlacklist(
      String token, int syncId) async {
    try {
      print(
          '[HomePage] 📊 Fetching fresh license info with dummy order request...');

      var dummyPayload = {
        "partyCd": "",
        "lat": "0",
        "longi": "0",
        "narration": "Blacklist check",
        "moduleNo": "205",
      };

      final ordersURL = "${AppConfig.baseURL}orders";
      final response = await http.post(
        Uri.parse(ordersURL),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
        body: dummyPayload,
      );

      print("[HomePage] $ordersURL");
      print('[HomePage] 📊 /api/orders response: ${response.statusCode}');

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 400) {
        final data = jsonDecode(response.body);
        final licenseInfo = data['licenseInfo'];

        if (licenseInfo != null) {
          print(
              '[HomePage] 📊 Got fresh license info: orderCount=${licenseInfo['orderCount']}, maxOrders=${licenseInfo['maxOrders']}, blacklisted=${licenseInfo['autoBlacklisted']}');

          // Cache the fresh license info
          await DatabaseHelper().cacheLicenseInfo(
            syncId: syncId,
            orderCount: licenseInfo['orderCount'] as int? ?? 0,
            maxOrders: licenseInfo['maxOrders'] as int? ?? 0,
            autoBlacklisted: licenseInfo['autoBlacklisted'] == true,
            renewalTriggered: false,
          );

          print('[HomePage] ✅ Fresh license info cached');
        }
      }
    } catch (e) {
      print('[HomePage] ⚠️ Error fetching fresh license info: $e');
    }
  }

  /// Fetch license info from the dedicated license-info endpoint using CUST_ID
  /// API: GET {baseURL}/license-info/:CUST_ID
  /// Response: { orderCount, maxOrders }
  Future<void> _fetchLicenseInfoFromLicenseInfoEndpoint(
      String token, int syncId, String custId) async {
    try {
      print(
          '[HomePage] 📊 Fetching license info from license-info endpoint with custId=$custId...');

      final response = await http.get(
        Uri.parse("${AppConfig.baseURL}license-info/$custId"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      );

      print("[HomePage] ${AppConfig.baseURL}license-info/$custId");
      print(
          '[HomePage] 📊 /api/license-info/$custId response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        print(
            '[HomePage] 📊 Got license info: orderCount=${data['orderCount']}, maxOrders=${data['maxOrders']}');

        // Cache the license info
        await DatabaseHelper().cacheLicenseInfo(
          syncId: syncId,
          orderCount: data['orderCount'] as int? ?? 0,
          maxOrders: data['maxOrders'] as int? ?? 0,
          autoBlacklisted: false,
          renewalTriggered: false,
        );

        print('[HomePage] ✅ License info cached from license-info endpoint');
      } else {
        print(
            '[HomePage] ⚠️ Failed to fetch license info: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print(
          '[HomePage] ⚠️ Error fetching license info from license-info endpoint: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Remove listener to prevent memory leaks
    _profileProvider.removeListener(_handlePendingWarning);
    // Unmark HomePage active
    Global.isHomeActive = false;
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
    // TODO: implement setState
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final UserProvider ub = context.watch<UserProvider>();
    final ProfileProvider p = context.watch<ProfileProvider>();
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final Global global = context.watch<Global>();
    final LocationProvider location = context.watch<LocationProvider>();
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.white, // 👈 makes drawer/menu icon white
          ),
          title: GestureDetector(
              onTap: () {
                log('Home title tapped');
                CrashlyticsService.logAction('home_title_tapped');
              },
              //child: Text(p.data != null
              //    ? Helper.trimValue(p.data!.compName.toString(), 30)
              //    : "")
              // child: PopupMenuButton<int>(
              //   child: Container(
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.start,
              //       children: [
              //         Flexible(
              //           child: Text(
              //             ub.syncName ?? "No Name",
              //             maxLines: 1,
              //             textAlign: TextAlign.center,
              //             style: TextStyle(
              //                 color: Colors.white, fontWeight: FontWeight.w800),
              //           ),
              //         ),
              //         SizedBox(
              //           width: 10,
              //         ),
              //         Container(
              //             width: 20,
              //             height: 30,
              //             decoration: BoxDecoration(
              //               borderRadius: BorderRadius.circular(8),
              //               color: Colors.lightBlue.shade100,
              //             ),
              //             child: Row(
              //               children: [
              //                 Icon(
              //                   Icons.keyboard_double_arrow_down_rounded,
              //                   color: Color(0XFF2c9ed9),
              //                   size: 20,
              //                 )
              //               ],
              //             ))
              //       ],
              //     ),
              //   ),
              //   onSelected: (int? newValue) {
              //     setState(() {
              //       selectedSyncId = newValue;
              //
              //       selectedFirmName = firmList.firstWhere(
              //         (firm) => firm['syncId'] == newValue,
              //         orElse: () => {'firmName': 'Unknown'},
              //       )['firmName'];
              //
              //       final UserProvider ub =
              //           Provider.of<UserProvider>(context, listen: false);
              //
              //       ub.saveSyncId(newValue.toString());
              //       ub.saveSyncName(selectedFirmName);
              //
              //       final PartyProvider party =
              //       Provider.of<PartyProvider>(context,
              //           listen: false);
              //       party.clearParty();
              //       party.clearPunchInOutParty();
              //
              //       // Fluttertoast.showToast(
              //       //     msg: 'Please wait, loading firm data...');
              //
              //       AppSnackBar.showGetXCustomSnackBar(message:'Please wait, loading firm data...',backgroundColor: Colors.green);
              //
              //       Authservices()
              //           .fetchlogin(
              //               selectedSyncId.toString(), ub.token!, context)
              //           .then((value) {
              //         if (value != null) {
              //           ub
              //               .saveUserData(value["role"] ?? "", value["token"])
              //               .then((value) {
              //             ub.setSignIn().then((value) {
              //               context.read<LocationProvider>().start(context);
              //               context.read<PartyProvider>().getpartyname(context);
              //               context.read<ItemListProvider>().getItems(context);
              //               context
              //                   .read<ProfileProvider>()
              //                   .getProfile(context)
              //                   .then((value) {
              //                 Get.offAll(() => BottomnavigationBarScreen());
              //               });
              //             });
              //           });
              //         }
              //       });
              //     });
              //   },
              //   itemBuilder: (BuildContext context) {
              //     return firmList.map((firm) {
              //       return PopupMenuItem<int>(
              //         value: firm['syncId'],
              //         child: Text(
              //           firm['firmName'],
              //           style: TextStyle(fontSize: 18.0),
              //         ),
              //       );
              //     }).toList();
              //   },
              // )

              child: PopupMenuButton<int>(
                constraints: BoxConstraints(
                  minWidth:
                      MediaQuery.of(context).size.width, // Set desired width
                ),
                //offset: Offset(0, 50),
                child: Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ub.syncName ?? "No Name",
                          maxLines: 1,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 30,
                      ),
                      // Container(
                      //     width: 20,
                      //     height: 30,
                      //     decoration: BoxDecoration(
                      //       borderRadius: BorderRadius.circular(8),
                      //       color: Colors.lightBlue.shade100,
                      //     ),
                      //     child: Row(
                      //       children: [
                      //         Icon(
                      //           Icons.keyboard_double_arrow_down_rounded,
                      //           color: Color(0XFF2c9ed9),
                      //           size: 20,
                      //         )
                      //       ],
                      //     ))
                    ],
                  ),
                ),
                onSelected: (int? newValue) {
                  setState(() async {
                    selectedSyncId = newValue;

                    selectedFirmName = firmList.firstWhere(
                      (firm) => firm['syncId'] == newValue,
                      orElse: () => {'firmName': 'Unknown'},
                    )['firmName'];

                    final UserProvider ub =
                        Provider.of<UserProvider>(context, listen: false);

                    ub.saveSyncId(newValue.toString());
                    ub.saveSyncName(selectedFirmName);

                    final PartyProvider party =
                        Provider.of<PartyProvider>(context, listen: false);
                    party.clearParty();
                    party.clearPunchInOutParty();
                    final productController =
                        Get.isRegistered<ProductController>()
                            ? Get.find<ProductController>()
                            : Get.put(ProductController());
                    await productController.clearPartySelection();

                    // Reset punch state so new firm's homepage doesn't inherit old firm's state
                    final profileProvider =
                        Provider.of<ProfileProvider>(context, listen: false);
                    profileProvider.setPunchState(false); // <-- add this

                    // Fluttertoast.showToast(
                    //     msg: 'Please wait, loading firm data...');

                    AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please wait, loading firm data...',
                        backgroundColor: Colors.green);

                    AuthServices()
                        .changeFirmLogin(
                            selectedSyncId.toString(), ub.token!, context)
                        .then((value) async {
                      if (value != null) {
                        // Clear auto-cache flag for new firm
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final cacheKey =
                              'auto_cached_firm_${selectedSyncId.toString()}';
                          await prefs.remove(cacheKey);
                          print(
                              '[HomePage] Cleared auto-cache flag for firm $selectedSyncId');
                        } catch (e) {
                          print(
                              '[HomePage] Failed to clear auto-cache flag: $e');
                        }

                        // Preserve existing role if the response doesn't include one
                        final currentRole = ub.role ?? "";
                        final newRole = value["role"] ?? currentRole;
                        print(
                            '[HomePage] Role preservation: current=$currentRole, API=${{
                          value["role"]
                        }}, using=$newRole');

                        ub.saveUserData(newRole, value["token"]).then((value) {
                          ub.setSignIn().then((value) {
                            final locationProvider =
                                Provider.of<LocationProvider>(context,
                                    listen: false);
                            final userProvider = Provider.of<UserProvider>(
                                context,
                                listen: false);
                            locationProvider.start(userProvider);
                            //context.read<LocationProvider>().start(context);
                            context.read<PartyProvider>().getpartyname(context);
                            context.read<ItemListProvider>().getItems(context);
                            context
                                .read<ProfileProvider>()
                                .getProfile()
                                .then((value) async {
                              // Load settings after profile is loaded
                              try {
                                await (context.read<ProfileProvider>()
                                        as dynamic)
                                    .loadSettings(context);
                              } catch (e) {
                                print(
                                    '[HomePage] loadSettings fallback failed: $e');
                              }

                              Get.offAll(() => BottomnavigationBarScreen());
                            });
                          });
                        });
                      }
                    });
                  });
                },
                itemBuilder: (BuildContext context) {
                  return firmList.map((firm) {
                    return PopupMenuItem<int>(
                      value: firm['syncId'],
                      child: Text(
                        firm['firmName'],
                        style: TextStyle(fontSize: 18.0),
                      ),
                    );
                  }).toList();
                },
              )),
          centerTitle: false,
          // actions: [
          //   // GO OFFLINE Button - Cache all data manually
          //   Padding(
          //     padding: const EdgeInsets.only(right: 8.0),
          //     child: Tooltip(
          //       message: 'Download data for offline use',
          //       child: GestureDetector(
          //         onTap: () {
          //           _showOfflineCachingDialog();
          //         },
          //         child: Container(
          //           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //           decoration: BoxDecoration(
          //             color: Colors.white.withOpacity(0.2),
          //             borderRadius: BorderRadius.circular(6),
          //             border: Border.all(color: Colors.white, width: 1),
          //           ),
          //           child: Row(
          //             mainAxisSize: MainAxisSize.min,
          //             children: [
          //               Icon(Icons.cloud_download,
          //                   color: Colors.white, size: 18),
          //               SizedBox(width: 6),
          //               Text(
          //                 'GO OFFLINE',
          //                 style: TextStyle(
          //                   color: Colors.white,
          //                   fontSize: 12,
          //                   fontWeight: FontWeight.w600,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          //
          //   // Logout Icon (Hidden by Visibility)
          //   Visibility(
          //     visible: false, // Change to true if needed
          //     child: Padding(
          //       padding: const EdgeInsets.only(right: 12.0),
          //       child: GestureDetector(
          //         onTap: () {
          //           ub.userSignout(context).then((value) {
          //             Get.offAll(() => LoginPage());
          //           });
          //         },
          //         child: Icon(Icons.logout),
          //       ),
          //     ),
          //   ),
          //
          //   // Show a Loading Spinner (While Fetching Data)
          //   isLoading
          //       ? CircularProgressIndicator(
          //           color: Colors.white,
          //           strokeWidth: 2.0,
          //         )
          //       : SizedBox(
          //           width: 0.1,
          //         ),
          // ],
          actions: [
            IconButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content:
                            Text("You don't have any notification for now."),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("OK"))
                        ],
                      );
                    });
              },
              icon: Icon(Icons.notifications_none),
            )
          ],
        ),
        drawer: CommonAppDrawer(
          narrationModuleNo: narrationModuleNo,
          narrationReadRight: narrationReadRight,
          narrationWriteRights: narrationWriteRights,
          narrationUpdateRights: narrationUpdateRights,
          narrationDeleteRight: narrationDeleteRight,
          narrationPrintRights: narrationPrintRights,
        ),
        // drawer: Drawer(
        //   backgroundColor: Colors.white,
        //   child: ListView(
        //     padding: EdgeInsets.zero,
        //     children: [
        //       // DrawerHeader(
        //       //   decoration: BoxDecoration(
        //       //     color: Colors.white,
        //       //   ),
        //       //   child: Column(
        //       //     mainAxisAlignment: MainAxisAlignment.start,
        //       //     crossAxisAlignment: CrossAxisAlignment.start,
        //       //     children: [
        //       //       // Adjust the position of the image
        //       //       Image.asset(
        //       //         'assets/Arham-icon.png',
        //       //         width: MediaQuery.of(context).size.width *
        //       //             0.55, // Responsive width
        //       //         height: MediaQuery.of(context).size.height *
        //       //             0.14, // Responsive height
        //       //       ),
        //       //       // Text("hello")
        //       //     ],
        //       //   ),
        //       // ),
        //
        //       DrawerHeader(
        //         decoration: BoxDecoration(
        //           color: Colors.white,
        //         ),
        //         child: Column(
        //           mainAxisAlignment: MainAxisAlignment.start,
        //           crossAxisAlignment: CrossAxisAlignment.start,
        //           children: [
        //             Flexible(
        //               child: Image.asset(
        //                 'assets/arhamOMS_icon.png',
        //                 fit: BoxFit.contain,
        //                 width: MediaQuery.of(context).size.width * 0.55,
        //                 // Don't use full screen height here
        //                 height: MediaQuery.of(context).size.height *
        //                     0.14, // Reduce height
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //
        //       // FAZAL Changes 15-12-2025
        //       // ListTile(
        //       //   leading: Icon(
        //       //     Icons.home,
        //       //     size: 30,
        //       //   ),
        //       //   title: Text(
        //       //     'Home',
        //       //     style: TextStyle(
        //       //       fontSize: 20,
        //       //     ),
        //       //   ),
        //       //   onTap: () {
        //       //     //Get.to(() => HomePage());
        //       //     Get.offAll(() =>
        //       //         BottomnavigationBarScreen()); // FAZAL Changes 14-02-2025
        //       //   },
        //       // ),
        //       // ADD : FAZAL Changes 15-12-2025
        //       // ListTile(
        //       //   leading: Icon(
        //       //     Icons.widgets_outlined,
        //       //     size: 30,
        //       //   ),
        //       //   title: Text(
        //       //     'Menus',
        //       //     style: TextStyle(
        //       //       fontSize: 20,
        //       //     ),
        //       //   ),
        //       //   onTap: () {
        //       //     Get.to(() => NewMenu());
        //       //   },
        //       // ),
        //       // if (p.data?.modulesList != null &&
        //       //     p.data!.modulesList!.any((module) =>
        //       //         module.mODULENO == "301" &&
        //       //         module.rEADRIGHT == true))
        //       //   ListTile(
        //       //     leading: Icon(
        //       //       Icons.dashboard,
        //       //       size: 30,
        //       //     ),
        //       //     title: Text(
        //       //       'DashBoard',
        //       //       style: TextStyle(fontSize: 20),
        //       //     ),
        //       //     onTap: () {
        //       //       Get.to(() => DailyReportScreen());
        //       //     },
        //       //   ),
        //       if (p.data != null &&
        //           p.data!.modulesList!.any((module) =>
        //               module.mODULENO == "109" && module.rEADRIGHT == true))
        //         ListTile(
        //           leading: Icon(
        //             Icons.nat_rounded,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'Narration',
        //             style: TextStyle(fontSize: 20),
        //           ),
        //           onTap: () {
        //             Get.to(NarrationView(), arguments: {
        //               "ModuleNo": narrationModuleNo,
        //               "ReadRight": narrationReadRight,
        //               "WriteRight": narrationWriteRights,
        //               "UpdateRight": narrationUpdateRights,
        //               "DeleteRight": narrationDeleteRight,
        //               "PrintRight": narrationPrintRights,
        //             });
        //           },
        //         ),
        //       if (ub.role == AppConfig.masteruser)
        //         ListTile(
        //           leading: Icon(
        //             Icons.business_sharp,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'Firm Management',
        //             style: TextStyle(fontSize: 20),
        //           ),
        //           onTap: () {
        //             Get.to(() => FirmListPage());
        //           },
        //         ),
        //       if (p.data != null &&
        //           p.data!.modulesList!.any((module) =>
        //               module.mODULENO == "110" && module.rEADRIGHT == true))
        //         ListTile(
        //           leading: Icon(
        //             Icons.group,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'User Management',
        //             style: TextStyle(
        //               fontSize: 20,
        //             ),
        //           ),
        //           onTap: () {
        //             Get.to(() => UserScreen());
        //           },
        //         ),
        //       // ListTile(
        //       //   leading: Icon(
        //       //     Icons.account_circle,
        //       //     size: 30,
        //       //   ),
        //       //   title: Text(
        //       //     'Profile',
        //       //     style: TextStyle(fontSize: 20),
        //       //   ),
        //       //   onTap: () {
        //       //     Get.to(() => ProfilePage());
        //       //   },
        //       // ),
        //       if (ub.role == AppConfig.masteruser)
        //         ListTile(
        //           leading: Icon(
        //             Icons.settings,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'Settings',
        //             style: TextStyle(
        //               fontSize: 20,
        //             ),
        //           ),
        //           onTap: () {
        //             Get.to(() => SettingScreen());
        //           },
        //         ),
        //       // ✅ Show Go Offline button only if offline mode is enabled
        //       Selector<ProfileProvider, bool>(
        //         selector: (context, profileProvider) =>
        //             profileProvider.isOfflineModeEnabled(),
        //         builder: (context, isOfflineModeEnabled, child) {
        //           if (!isOfflineModeEnabled) {
        //             print(
        //                 '[HomePage] Offline mode disabled - hiding Go Offline button');
        //             return SizedBox.shrink(); // Hide if offline mode disabled
        //           }
        //           print(
        //               '[HomePage] Offline mode enabled - showing Go Offline button');
        //           return ListTile(
        //             leading: Icon(
        //               Icons.cloud_download,
        //               size: 30,
        //             ),
        //             title: Text(
        //               'Go Offline',
        //               style: TextStyle(
        //                 fontSize: 20,
        //               ),
        //             ),
        //             onTap: () {
        //               _showOfflineCachingDialog();
        //             },
        //           );
        //         },
        //       ),
        //       ListTile(
        //         leading: Icon(
        //           Icons.key,
        //           size: 30,
        //         ),
        //         title: Text(
        //           'Change Password',
        //           style: TextStyle(
        //             fontSize: 20,
        //           ),
        //         ),
        //         onTap: () {
        //           Get.to(() => ChangePasswordView());
        //         },
        //       ),
        //       if (p.data != null &&
        //           p.data!.modulesList!.any((module) =>
        //               module.mODULENO == "232" &&
        //               module.rEADRIGHT == true)) ...[
        //         ListTile(
        //           leading: Icon(
        //             Icons.add_task,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'Assign Tasks',
        //             style: TextStyle(
        //               fontSize: 20,
        //             ),
        //           ),
        //           onTap: () {
        //             Get.to(() => AssignTaskView());
        //           },
        //         ),
        //         ListTile(
        //           leading: Icon(
        //             Icons.task,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'View Tasks',
        //             style: TextStyle(
        //               fontSize: 20,
        //             ),
        //           ),
        //           onTap: () {
        //             Get.to(() => TaskListView());
        //           },
        //         ),
        //       ],
        //       ListTile(
        //         leading: Icon(
        //           Icons.group_add,
        //           size: 30,
        //         ),
        //         title: Text(
        //           'Generate Referral',
        //           style: TextStyle(
        //             fontSize: 20,
        //           ),
        //         ),
        //         onTap: () {
        //           Get.to(() => ReferralView());
        //         },
        //       ),
        //       // Reimbursement (Module 231)
        //       if (_profileProvider.data?.modulesList != null &&
        //           _profileProvider.data!.modulesList!.any((module) =>
        //               module.mODULENO == "231" &&
        //               (module.rEADRIGHT == true || module.pRINTRIGHT == true)))
        //         ListTile(
        //           leading: Icon(
        //             Icons.attach_money,
        //             size: 30,
        //           ),
        //           title: Text(
        //             'Reimbursement',
        //             style: TextStyle(
        //               fontSize: 20,
        //             ),
        //           ),
        //           onTap: () {
        //             Get.to(() => GetExpenseView());
        //           },
        //         ),
        //       ListTile(
        //         leading: Icon(
        //           Icons.info_outline,
        //           size: 30,
        //         ),
        //         title: Text(
        //           'About Us',
        //           style: TextStyle(
        //             fontSize: 20,
        //           ),
        //         ),
        //         onTap: () {
        //           Get.to(() => AboutPage());
        //         },
        //       ),
        //       ListTile(
        //         leading: Icon(
        //           Icons.logout,
        //           color: Colors.red,
        //           size: 30,
        //         ),
        //         title: Text(
        //           'Logout',
        //           style: TextStyle(
        //             fontSize: 20,
        //           ),
        //         ),
        //         onTap: () {
        //           // Show confirmation dialog
        //           showDialog(
        //             context: context,
        //             builder: (BuildContext context) {
        //               return AlertDialog(
        //                 title: Text('Logout Confirmation'),
        //                 content: Text('Are you sure you want to log out?'),
        //                 actions: [
        //                   TextButton(
        //                     onPressed: () {
        //                       // Cancel button: Close the dialog
        //                       Navigator.of(context).pop();
        //                     },
        //                     child: Text('Cancel'),
        //                   ),
        //                   TextButton(
        //                     onPressed: () {
        //                       // Confirm logout
        //                       Navigator.of(context).pop(); // Close the dialog
        //                       ub.userSignout(context).then((value) {
        //                         Get.offAll(() => LoginPage());
        //                       });
        //                     },
        //                     child: Text('Logout'),
        //                   ),
        //                 ],
        //               );
        //             },
        //           );
        //         },
        //       ),
        //     ],
        //   ),
        // ),
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: size.height,
                width: size.width,
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          _getGreetingMessage(),
                          style: TextStyle(
                            fontSize: 16,
                            // color: Color(0XFF2c9ed9),
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          // p.userName!.toString() +
                          //     " (" +
                          //     p.userCode!.toString() +
                          //     ")", // User Name + User Code
                          p.userName.toString(), // User Name + User Code
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.only(
                  //     left: 20,
                  //     bottom: 10,
                  //   ),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         // p.userName!.toString() +
                  //         //     " (" +
                  //         //     p.userCode!.toString() +
                  //         //     ")", // User Name + User Code
                  //         p.userName.toString(), // User Name + User Code
                  //         style: TextStyle(
                  //             color: Colors.black,
                  //             fontSize: 20,
                  //             fontWeight: FontWeight.bold,
                  //             letterSpacing: 1),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL ORDERS',
                              style: TextStyle(
                                  fontSize: 13,
                                  // color: Color(0XFF2c9ed9),
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "₹ ${data != null ? Helper.parseNumericValue(data!.data.labelData.totalSales.toString()) : 0}",
                              style: TextStyle(
                                color: Color(0XFF2c9ed9),
                                fontWeight: FontWeight.w600,
                                fontSize: 17.sp,
                              ),
                            ),
                          ],
                        ),
                        (selectedFirmLogo != null &&
                                selectedFirmLogo!.isNotEmpty)
                            ? Container(
                                width: 160,
                                height: 40,
                                alignment: Alignment.centerRight,
                                child: Image.network(
                                  selectedFirmLogo!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.store,
                                    size: 36,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : SizedBox.shrink(),
                      ],
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.only(left: 20),
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         "₹ ${data != null ? Helper.parseNumericValue(data!.data.labelData.totalSales.toString()) : 0}",
                  //         style: TextStyle(
                  //           color: Color(0XFF2c9ed9),
                  //           fontWeight: FontWeight.w600,
                  //           fontSize: 17.sp,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  if (data?.data.labelData.targetAchievement?.target != 0) ...[
                    Builder(
                      builder: (context) {
                        final ta = data?.data.labelData.targetAchievement;
                        final double target = ta?.target ?? 0.0;
                        final double achieved = ta?.achieved ?? 0.0;
                        final percent =
                            _calculateProgressPercent(achieved, target);
                        final targetText =
                            'Target: ₹${Helper.parseNumericValue(target.toStringAsFixed(2))}';

                        return Padding(
                          padding: EdgeInsets.only(
                            top: 5,
                            right: 20,
                            left: 20,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    targetText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xff006705),
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    "${percent.toStringAsFixed(2)}%",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: percent > 100
                                          ? Color(0xFFDFA906)
                                          : percent > 0
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              _buildOverflowProgressBar(percent),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      height: 10,
                    ),
                  ] else ...[
                    Divider(
                      thickness: 0.8,
                      indent: 20,
                      endIndent: 20,
                    ),
                  ],

                  // Define a common size for the boxes

                  Padding(
                    padding: const EdgeInsets.only(
                      // top: 8,
                      left: 8,
                      right: 8,
                    ),
                    child: Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Container(
                        padding: EdgeInsets.only(
                          // top: 10,
                          right: 10,
                          left: 10,
                        ),
                        // Add padding for better spacing
                        child: Column(
                          children: [
                            // Header Row with Title and Date
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10.0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  flex: 2,
                                                  child: Text(
                                                    "THIS MONTH",
                                                    style: TextStyle(
                                                      // fontSize: MediaQuery.of(context)
                                                      //         .size
                                                      //         .width *
                                                      //     0.04,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  // child: Text(
                                                  //   "TODAY'S ORDER",
                                                  //   style: TextStyle(
                                                  //     // fontSize:
                                                  //     //     MediaQuery.of(context)
                                                  //     //             .size
                                                  //     //             .width *
                                                  //     //         0.045,
                                                  //     fontSize: 13,
                                                  //     fontWeight: FontWeight.bold,
                                                  //     color: Colors.grey.shade700,
                                                  //   ),
                                                  //   overflow: TextOverflow.ellipsis,
                                                  // ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      "₹ ",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.035,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${data != null ? Helper.parseNumericValue(data!.data.labelData.month.toString()) : 0}",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.04,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Flexible(
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 3,
                                                  horizontal: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Color(0xFFE2EEFD)),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 14,
                                                          color: Colors
                                                              .grey.shade700,
                                                        ),
                                                        SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                                  'd MMM yyyy')
                                                              .format(DateTime
                                                                  .now()),
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey.shade700,
                                                          ),
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ],
                                                    ),
                                                    // SizedBox(height: 2),
                                                    // Builder(builder: (ctx) {
                                                    //   try {
                                                    //     final beatCtrl = Get
                                                    //             .isRegistered<
                                                    //                 BeatController>()
                                                    //         ? Get.find<
                                                    //             BeatController>()
                                                    //         : Get.put(
                                                    //             BeatController());
                                                    //     final beats = beatCtrl
                                                    //         .getBeatsForDate(
                                                    //             DateTime.now());
                                                    //     final beatName =
                                                    //         beats.isNotEmpty
                                                    //             ? beats.first
                                                    //                 .beatName
                                                    //             : '';
                                                    //     if (beatName.isEmpty)
                                                    //       return SizedBox
                                                    //           .shrink();
                                                    //     return Row(
                                                    //       mainAxisSize:
                                                    //           MainAxisSize.min,
                                                    //       children: [
                                                    //         Icon(
                                                    //           Icons
                                                    //               .route_outlined,
                                                    //           size: 14,
                                                    //           color: Colors.grey
                                                    //               .shade700,
                                                    //         ),
                                                    //         SizedBox(
                                                    //           width: 5,
                                                    //         ),
                                                    //         Text(
                                                    //           beatName,
                                                    //           style: TextStyle(
                                                    //             fontSize: 14,
                                                    //             color: Colors
                                                    //                 .grey
                                                    //                 .shade700,
                                                    //             fontWeight:
                                                    //                 FontWeight
                                                    //                     .bold,
                                                    //           ),
                                                    //         ),
                                                    //       ],
                                                    //     );
                                                    //   } catch (e) {
                                                    //     return SizedBox
                                                    //         .shrink();
                                                    //   }
                                                    // }),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5),
                            if (p.data != null &&
                                p.data!.modulesList!.any((module) =>
                                    module.mODULENO == "236" &&
                                    module.rEADRIGHT == true)) ...[
                              FutureBuilder<MonthlyTargetItemModel?>(
                                future: _monthlyTargetFuture,
                                builder: (context, snapshot) {
                                  final currentMonthlySale = double.tryParse(
                                        (data?.data.labelData.month ?? '0')
                                            .toString()
                                            .replaceAll(',', ''),
                                      ) ??
                                      0.0;

                                  final pobItem = snapshot.data;
                                  final double target = pobItem == null
                                      ? 0.0
                                      : ((pobItem.primaryTargetAmount > 0)
                                          ? pobItem.primaryTargetAmount
                                          : pobItem.salesmanTargetAmount);
                                  final double progressPercent =
                                      _calculateProgressPercent(
                                          currentMonthlySale, target);

                                  return Padding(
                                    padding: EdgeInsets.only(
                                        right: 0, left: 0, bottom: 4),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "Target: ₹${Helper.parseNumericValue(target.toStringAsFixed(2))}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xff006705),
                                              ),
                                            ),
                                            Spacer(),
                                            Text(
                                              "${progressPercent.toStringAsFixed(2)}%",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: progressPercent > 100
                                                    ? Color(0xFFDFA906)
                                                    : progressPercent > 0
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade700,
                                                // color: progressPercent > 0
                                                //     ? Colors.green.shade700
                                                //     : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        _buildOverflowProgressBar(
                                          progressPercent,
                                          baseColor: Color(0XFF2c9ed9),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                height: 10,
                              ),
                            ] else ...[
                              Divider(
                                thickness: 0.8,
                              ),
                            ],
                            // Divider(
                            //   thickness: 0.8,
                            // ),
                            // SizedBox(
                            //     height: MediaQuery.of(context).size.height *
                            //         0.02), // Spacing between sections

                            // Row for "This Week" and "This Month" cards
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // "This Week" Card
                                Flexible(
                                  child: Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.42,
                                      // height:
                                      //     MediaQuery.of(context).size.height *
                                      //         0.14,
                                      // padding: EdgeInsets.symmetric(
                                      //     horizontal: 10, vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10.0)),
                                        // color: Color(0xFFE2EEFD),
                                        color: Colors.transparent,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "THIS WEEK",
                                            style: TextStyle(
                                              // fontSize: MediaQuery.of(context)
                                              //         .size
                                              //         .width *
                                              //     0.04,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Text(
                                                "₹ ",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.04,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  "${data != null ? Helper.parseNumericValue(data!.data.labelData.week.toString()) : 0}",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.04,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    width: MediaQuery.of(context).size.width *
                                        0.02), // Horizontal spacing

                                // "Today's Order" Card
                                Flexible(
                                  child: Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.42,
                                      // height:
                                      //     MediaQuery.of(context).size.height *
                                      //         0.14,
                                      // padding: EdgeInsets.symmetric(
                                      //     horizontal: 10, vertical: 15),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10.0)),
                                        color: Colors.transparent,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          // Text(
                                          //   "THIS MONTH",
                                          //   style: TextStyle(
                                          //     // fontSize: MediaQuery.of(context)
                                          //     //         .size
                                          //     //         .width *
                                          //     //     0.04,
                                          //     fontSize: 13,
                                          //     fontWeight: FontWeight.bold,
                                          //     color: Colors.grey.shade700,
                                          //   ),
                                          // ),
                                          Text(
                                            "TODAY'S ORDER",
                                            style: TextStyle(
                                              // fontSize:
                                              //     MediaQuery.of(context)
                                              //             .size
                                              //             .width *
                                              //         0.045,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                "₹ ",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .width *
                                                          0.04,
                                                ),
                                              ),
                                              Flexible(
                                                // child: Text(
                                                //   "${data != null ? Helper.parseNumericValue(data!.data.labelData.month.toString()) : 0}",
                                                //   style: TextStyle(
                                                //     color: Colors.black,
                                                //     fontWeight: FontWeight.w600,
                                                //     fontSize:
                                                //         MediaQuery.of(context)
                                                //                 .size
                                                //                 .width *
                                                //             0.04,
                                                //   ),
                                                //   overflow:
                                                //       TextOverflow.ellipsis,
                                                // ),
                                                child: Text(
                                                  "${data != null ? Helper.parseNumericValue(data!.data.labelData.today.toString()) : 0}",
                                                  style: TextStyle(
                                                    fontSize:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.04,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(
                              thickness: 0.8,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 3,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Color(0xFFE2EEFD)),
                                  child: Builder(builder: (ctx) {
                                    final singularRouteLabel =
                                        RouteLabelHelper.singularMaster(
                                            _profileProvider);
                                    try {
                                      final beatCtrl =
                                          Get.isRegistered<BeatController>()
                                              ? Get.find<BeatController>()
                                              : Get.put(BeatController());
                                      final beats = beatCtrl
                                          .getBeatsForDate(DateTime.now());
                                      final beatName = beats.isNotEmpty
                                          ? beats.first.beatName
                                          : '';
                                      if (beatName.isEmpty)
                                        return SizedBox.shrink();
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${singularRouteLabel} - ${beatName}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    } catch (e) {
                                      return SizedBox.shrink();
                                    }
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 450.0,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 0, left: 8, right: 8, bottom: 0),
                        child: Card(
                          color: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: EdgeInsets.only(
                                top: 0, left: 10, right: 10, bottom: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                //TODO : COMMENT 16/11/2024
                                Container(
                                  child: p.data != null &&
                                          DateTime(
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[0]),
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[1]),
                                                      int.parse(p.data!.license!
                                                          .licEndDate
                                                          .toString()
                                                          .split("-")[2]))
                                                  .difference(DateTime.now())
                                                  .inDays <=
                                              30 &&
                                          ub.role == AppConfig.masteruser
                                      ? Padding(
                                          padding:
                                              EdgeInsets.only(bottom: 14.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title:
                                                        Text('License Expire'),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              "Firm Information",
                                                              style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Firm Name: ${ub.syncName}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "License Start Date: ${p.data!.license!.licStartDate.toString()}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "License Expiry Date: ${p.data!.license!.licEndDate.toString()}"),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Contact: +91 917391 9797"),
                                                          SizedBox(height: 5),
                                                          Divider(
                                                            height: 1,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(height: 10),
                                                          Text(
                                                              "Email: info@arhamcorp.in"),
                                                          SizedBox(height: 20),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child:
                                                                    ElevatedButton(
                                                                  onPressed:
                                                                      () {
                                                                    Get.back();
                                                                  },
                                                                  style: ElevatedButton
                                                                      .styleFrom(
                                                                    shadowColor:
                                                                        Colors
                                                                            .transparent,
                                                                    backgroundColor:
                                                                        Colors
                                                                            .transparent,
                                                                    foregroundColor:
                                                                        Colors
                                                                            .green,
                                                                    side:
                                                                        BorderSide(
                                                                      color: Colors
                                                                          .green,
                                                                      width: 1,
                                                                    ),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .circular(
                                                                        15,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    "Renew License",
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    /*actions: <Widget>[
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop(); // Close the dialog
                                                        },
                                                        child: Text('OK'),
                                                      ),
                                                    ],*/
                                                  );
                                                },
                                              );
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0XFFFF6263)
                                                    .withOpacity(0.2),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(15.w),
                                                ),
                                              ),
                                              width: double.infinity,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.h,
                                                vertical: 10.h,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.info_outline,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 5.w),
                                                  Expanded(
                                                    child: Text(
                                                      "Your License is expiring in ${DateTime(
                                                        int.parse(p.data!
                                                            .license!.licEndDate
                                                            .toString()
                                                            .split("-")[0]),
                                                        int.parse(p.data!
                                                            .license!.licEndDate
                                                            .toString()
                                                            .split("-")[1]),
                                                        int.parse(p.data!
                                                            .license!.licEndDate
                                                            .toString()
                                                            .split("-")[2]),
                                                      ).difference(DateTime.now()).inDays} days.",
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      : Container(),
                                ),
                                Container(
                                  padding: EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsets.only(bottom: 14.0),
                                            child: Text(
                                                "${data != null ? "${data!.data.label}:" : ""}",
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.8)),
                                          ),
                                        ],
                                      ),
                                      // if (p.data?.profileSettings
                                      //             .firstWhere((element) =>
                                      //                 element.variable ==
                                      //                 'punchInOut')
                                      //             .value ==
                                      //         'Y' &&
                                      //     location.isLoading == false)

                                      if ((p.data?.profileSettings.any((e) =>
                                                  e.variable == 'punchInOut' &&
                                                  e.value == 'Y') ??
                                              false) &&
                                          location.isLoading == false)
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (p.data?.isPunchIn == true) {
                                                  // Show confirmation dialog before punch out
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                            context: context,
                                                            barrierDismissible:
                                                                false,
                                                            builder: (BuildContext
                                                                    dialogContext) =>
                                                                AlertDialog(
                                                              title: const Text(
                                                                'Confirm Punch Out',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              content:
                                                                  const Text(
                                                                'Thank you for your outstanding service today!\n\nAre you sure you want to punch out?',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        16),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            dialogContext)
                                                                        .pop(
                                                                            false);
                                                                  },
                                                                  child: const Text(
                                                                      'Cancel'),
                                                                ),
                                                                ElevatedButton(
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.of(
                                                                            dialogContext)
                                                                        .pop(
                                                                            true);
                                                                  },
                                                                  style: ElevatedButton
                                                                      .styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                  child:
                                                                      const Text(
                                                                    'Confirm Punch Out',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ) ??
                                                          false;

                                                  if (!confirmed) {
                                                    return; // User cancelled
                                                  }

                                                  // PUNCH OUT confirmed - execute end order API first
                                                  final hasActiveOrder = p
                                                          .ACC_NAME
                                                          .trim()
                                                          .isNotEmpty &&
                                                      p.ACC_CD
                                                          .trim()
                                                          .isNotEmpty;

                                                  if (hasActiveOrder) {
                                                    await party.startEndOrder(
                                                      p.ACC_NAME,
                                                      p.ACC_CD,
                                                      context,
                                                      "3",
                                                      id: 1,
                                                    );

                                                    final isOrderStillActive = p
                                                            .ACC_NAME
                                                            .trim()
                                                            .isNotEmpty &&
                                                        p.ACC_CD
                                                            .trim()
                                                            .isNotEmpty;
                                                    if (isOrderStillActive) {
                                                      AppSnackBar
                                                          .showGetXCustomSnackBar(
                                                        message:
                                                            'Unable to end active order. Please try again.',
                                                      );
                                                      return;
                                                    }
                                                  }

                                                  // PUNCH OUT confirmed - execute punch out logic
                                                  location
                                                      .setRemarks("PUNCH OUT");
                                                  // Clear stockist selection on punch out
                                                  final productController = Get
                                                          .isRegistered<
                                                              ProductController>()
                                                      ? Get.find<
                                                          ProductController>()
                                                      : Get.put(
                                                          ProductController());
                                                  productController
                                                      .clearStockistSelection();
                                                  await productController
                                                      .clearPartySelection();
                                                } else {
                                                  location
                                                      .setRemarks("PUNCH IN");
                                                }

                                                final userProvider =
                                                    Provider.of<UserProvider>(
                                                        context,
                                                        listen: false);
                                                final profileProvider = Provider
                                                    .of<ProfileProvider>(
                                                        context,
                                                        listen: false);
                                                await location.sendLocation(
                                                    userProvider,
                                                    profile: profileProvider);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            180)),
                                                backgroundColor:
                                                    p.data?.isPunchIn == true
                                                        ? Colors.red
                                                        : Colors.green,
                                              ),
                                              child: Text(
                                                p.data?.isPunchIn == true
                                                    ? "Punch Out"
                                                    : "Punch IN",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      // if (p.data?.profileSettings
                                      //             .firstWhere((element) =>
                                      //                 element.variable ==
                                      //                 'punchInOut')
                                      //             .value ==
                                      //         'Y' &&
                                      //     location.isLoading == true)

                                      if ((p.data?.profileSettings.any((e) =>
                                                  e.variable == 'punchInOut' &&
                                                  e.value == 'Y') ??
                                              false) &&
                                          location.isLoading == true)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 15.0),
                                          child: SizedBox(
                                              height: 20.0,
                                              width: 20.0,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3.0,
                                              )),
                                        )
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: nolist == true
                                      ? Center(
                                          child: Text("No List"),
                                        )
                                      : data == null
                                          ? Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          : ListView.separated(
                                              shrinkWrap: true,
                                              primary: false,
                                              itemCount: data!.data.labelData
                                                  .transaction.length,
                                              itemBuilder: (context, index) {
                                                final item = data!
                                                    .data
                                                    .labelData
                                                    .transaction[index];

                                                return GestureDetector(
                                                  onTap: () async {
                                                    if (p.data != null &&
                                                        p.data!.modulesList!
                                                            .any((module) =>
                                                                module.mODULENO ==
                                                                    "304" &&
                                                                module.rEADRIGHT ==
                                                                    true)) {
                                                      await global
                                                          .changePartyname(
                                                              item.name);
                                                      await party.changeParty(
                                                          item.name,
                                                          item.accCd,
                                                          context);

                                                      Get.to(() =>
                                                              OrderReportScreen())
                                                          ?.then((result) {
                                                        if (result == true) {
                                                          final party = Provider
                                                              .of<PartyProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
                                                          if (party.partyid
                                                              .isNotEmpty) {
                                                            getDashboarddata();
                                                            _fetchActiveTripStatus();
                                                          }
                                                        }
                                                      });
                                                    } else {
                                                      AppSnackBar
                                                          .showGetXCustomSnackBar(
                                                              message:
                                                                  'There is nothing to do.');
                                                    }
                                                  },
                                                  child: Card(
                                                    color: Colors.white,
                                                    elevation: 1,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 5,
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          /// INDEX CIRCLE (CENTER LEFT)
                                                          Container(
                                                            width: 24,
                                                            height: 24,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration:
                                                                const BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: Color(
                                                                  0XFF2c9ed9),
                                                            ),
                                                            child: Text(
                                                              "${index + 1}",
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                              width: 16),

                                                          /// NAME + MOBILE
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  item.name
                                                                      .toTitleCase(),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                  item.mobile,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                              width: 10),

                                                          /// AMOUNT + DATE
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                "₹ ${Helper.parseNumericValue(item.amount.toString())}",
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                Helper
                                                                    .convertToFormat(
                                                                  item.orderDate
                                                                      .toString(),
                                                                  'dd-MM-yyyy',
                                                                ),
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            12),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              separatorBuilder:
                                                  (BuildContext context,
                                                      int index) {
                                                return SizedBox(
                                                  height: 5,
                                                );
                                              },
                                            )

                                  // ListView.builder(
                                  //             itemCount: data!.data.labelData
                                  //                 .transaction.length,
                                  //             itemBuilder: (builder, index) {
                                  //               return GestureDetector(
                                  //                   onTap: () async {
                                  //                     if (p.data != null &&
                                  //                         p.data!.modulesList!
                                  //                             .any((module) =>
                                  //                                 module
                                  //                                     .mODULENO ==
                                  //                                 "304")) {
                                  //                       await global
                                  //                           .changePartyname(
                                  //                               data!
                                  //                                   .data
                                  //                                   .labelData
                                  //                                   .transaction[
                                  //                                       index]
                                  //                                   .name);
                                  //                       await party.changeParty(
                                  //                           data!
                                  //                               .data
                                  //                               .labelData
                                  //                               .transaction[
                                  //                                   index]
                                  //                               .name,
                                  //                           data!
                                  //                               .data
                                  //                               .labelData
                                  //                               .transaction[
                                  //                                   index]
                                  //                               .accCd,
                                  //                           context);
                                  //                       // Get.to(() =>
                                  //                       //     OrderReportScreen());
                                  //
                                  //                       Get.to(() =>
                                  //                               OrderReportScreen())
                                  //                           ?.then((result) {
                                  //                         if (result == true) {
                                  //                           final PartyProvider
                                  //                               party =
                                  //                               Provider.of<
                                  //                                       PartyProvider>(
                                  //                                   context,
                                  //                                   listen:
                                  //                                       false);
                                  //                           if (party.partyid !=
                                  //                               "") {
                                  //                             getDashboarddata();
                                  //                           } else {}
                                  //                         }
                                  //                       });
                                  //                     }
                                  //                   },
                                  //                   child: Card(
                                  //                       elevation: 4,
                                  //                       shape:
                                  //                           RoundedRectangleBorder(
                                  //                         borderRadius:
                                  //                             BorderRadius
                                  //                                 .circular(6),
                                  //                       ),
                                  //                       child: Padding(
                                  //                           padding:
                                  //                               const EdgeInsets
                                  //                                   .all(8.0),
                                  //                           child: Row(
                                  //                             mainAxisAlignment:
                                  //                                 MainAxisAlignment
                                  //                                     .start,
                                  //                             children: [
                                  //                               // Leading widget
                                  //                               Padding(
                                  //                                 padding:
                                  //                                     const EdgeInsets
                                  //                                         .only(
                                  //                                         bottom:
                                  //                                             13),
                                  //                                 child: Column(
                                  //                                   children: [
                                  //                                     Stack(
                                  //                                       alignment:
                                  //                                           Alignment.center,
                                  //                                       children: [
                                  //                                         // Circle decoration
                                  //                                         Container(
                                  //                                           width:
                                  //                                               30.0,
                                  //                                           // Diameter of the circle
                                  //                                           height:
                                  //                                               30.0,
                                  //                                           decoration: BoxDecoration(
                                  //                                               shape: BoxShape.circle,
                                  //                                               color: Color(0XFF2c9ed9) // Circle color
                                  //                                               ),
                                  //                                         ),
                                  //                                         // Text inside the circle
                                  //                                         Text(
                                  //                                           "${index + 1}",
                                  //                                           style:
                                  //                                               TextStyle(
                                  //                                             fontSize: 14,
                                  //                                             fontWeight: FontWeight.bold,
                                  //                                             color: Colors.white, // Text color
                                  //                                           ),
                                  //                                         ),
                                  //                                       ],
                                  //                                     ),
                                  //                                     // Your existing text below the circle
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                               SizedBox(
                                  //                                   width: 20),
                                  //                               // Spacer between leading and title
                                  //
                                  //                               // Expanded widget to allow title and subtitle to share available space
                                  //                               Expanded(
                                  //                                 child: Column(
                                  //                                   crossAxisAlignment:
                                  //                                       CrossAxisAlignment
                                  //                                           .start,
                                  //                                   children: [
                                  //                                     // Title
                                  //                                     Text(
                                  //                                       data!
                                  //                                           .data
                                  //                                           .labelData
                                  //                                           .transaction[index]
                                  //                                           .name
                                  //                                           .toTitleCase(),
                                  //                                       style:
                                  //                                           TextStyle(
                                  //                                         fontSize:
                                  //                                             14,
                                  //                                         fontWeight:
                                  //                                             FontWeight.bold,
                                  //                                         letterSpacing:
                                  //                                             0.5,
                                  //                                       ),
                                  //                                       overflow:
                                  //                                           TextOverflow.ellipsis, // Prevents overflow
                                  //                                     ),
                                  //                                     SizedBox(
                                  //                                       height:
                                  //                                           5,
                                  //                                     ),
                                  //                                     // Subtitle
                                  //                                     Text(
                                  //                                       data!
                                  //                                           .data
                                  //                                           .labelData
                                  //                                           .transaction[index]
                                  //                                           .mobile,
                                  //                                       style: TextStyle(
                                  //                                           fontSize:
                                  //                                               12),
                                  //                                       overflow:
                                  //                                           TextOverflow.ellipsis, // Prevents overflow
                                  //                                     ),
                                  //                                   ],
                                  //                                 ),
                                  //                               ),
                                  //                               SizedBox(
                                  //                                   width: 8),
                                  //                               // Spacer between title and trailing
                                  //
                                  //                               // Trailing widget
                                  //                               Column(
                                  //                                 children: [
                                  //                                   Text(
                                  //                                     "₹ ${Helper.parseNumericValue(data!.data.labelData.transaction[index].amount.toString())}",
                                  //                                     style: TextStyle(
                                  //                                         fontWeight: FontWeight
                                  //                                             .bold,
                                  //                                         fontSize:
                                  //                                             14,
                                  //                                         color:
                                  //                                             Colors.green),
                                  //                                   ),
                                  //                                   SizedBox(
                                  //                                     height: 5,
                                  //                                   ),
                                  //                                   Text(
                                  //                                     Helper.convertToFormat(
                                  //                                         data!
                                  //                                             .data
                                  //                                             .labelData
                                  //                                             .transaction[index]
                                  //                                             .orderDate
                                  //                                             .toString(),
                                  //                                         'dd-MM-yyyy'),
                                  //                                     style: TextStyle(
                                  //                                         fontSize:
                                  //                                             12),
                                  //                                     overflow:
                                  //                                         TextOverflow
                                  //                                             .ellipsis, // Prevents overflow
                                  //                                   ),
                                  //                                 ],
                                  //                               ),
                                  //                             ],
                                  //                           ))));
                                  //             })
                                  ,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Future<void> loadData() async {
    // Fetch firm list (simulating API call or other data source)
    fetchData();

    // Fetch stored syncId from SharedPreferences
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    await ub.getSyncId();
    String? storedSyncId = ub.syncId;

    setState(() {
      isLoading = false;
      if (storedSyncId != null) {
        selectedSyncId = int.tryParse(storedSyncId);

        // Set the selectedFirmName based on syncId
        if (selectedSyncId != null) {
          final firm = firmList.firstWhere(
            (firm) => firm['syncId'] == selectedSyncId,
            orElse: () => {},
          );
          selectedFirmName = firm.isNotEmpty ? firm['firmName'] : null;
        }
      }
    });
  }

  Future<void> fetchData() async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    final url = Uri.parse(AppConfig.baseURL + 'firm');

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token!}",
          'x-app-type': 'oms',
        },
      );

      // Keep full raw payload log for debugging exact server response.
      print(url);
      print("Dashboard Firm Data " + response.body);
      print('[HomePage] /firm response status=${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        final allSyncIds = firms
            .map((f) =>
                (f is Map<String, dynamic>) ? f['SYNC_ID']?.toString() : null)
            .whereType<String>()
            .toList();
        final selectedSyncId = ub.syncId?.toString();
        final selectedFirm = firms.cast<Map<String, dynamic>?>().firstWhere(
              (f) =>
                  (f?['SYNC_ID']?.toString() ?? '') == (selectedSyncId ?? ''),
              orElse: () => null,
            );

        final selectedModulesRaw =
            selectedFirm?['MODULE_NOS']?.toString().trim() ?? '';
        final selectedModuleCount = selectedModulesRaw.isEmpty
            ? 0
            : selectedModulesRaw
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toSet()
                .length;

        print(
            '[HomePage] /firm syncIds=$allSyncIds, selectedSyncId=$selectedSyncId, selectedFirmFound=${selectedFirm != null}, selectedModuleCount=$selectedModuleCount');
        print('[HomePage] /firm selectedFirmRaw=${selectedFirm ?? {}}');

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          firmList = firms.map((item) {
            return {
              "firmName":
                  item['FIRM_NAME']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                      'Unnamed Firm',
              "syncId": item['SYNC_ID'],
            };
          }).toList();
          // Save selected firm's logo URL for homepage display
          selectedFirmLogo = selectedFirm?['FIRM_LOGO']?.toString() ?? '';
          selectedFirmName = selectedFirm?['FIRM_NAME']?.toString() ?? '';
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  /// Auto-cache all data on first login without requiring user confirmation
  /// This runs only once per firm (tracked by SharedPreferences key: auto_cached_firm_SYNCID)
  /// Caching starts automatically immediately after dialog is shown
  void _showAutoOfflineCachingDialog(String syncId) {
    bool isCaching = true; // Start caching immediately
    bool cachingComplete = false;
    List<CacheItemStatus> cacheItems = [
      CacheItemStatus(name: 'Profile'),
      CacheItemStatus(name: 'Departments'),
      CacheItemStatus(name: 'Products'),
      CacheItemStatus(name: 'Party'),
      CacheItemStatus(name: 'Cart'),
    ];
    String? failureMessage;
    bool _cachingStarted =
        false; // Track if we've already started the async operation

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Auto-start caching on first build
            if (!_cachingStarted) {
              _cachingStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await OfflineCachingService.cacheAllDataForOffline(
                    context,
                    onProgress: (status) {
                      if (mounted && dialogContext.mounted) {
                        setDialogState(() {
                          // Find and update the matching item
                          final index = cacheItems
                              .indexWhere((item) => item.name == status.name);
                          if (index != -1) {
                            cacheItems[index] = status;
                          }

                          // Check for failure
                          if (!status.isSuccess && status.isComplete) {
                            failureMessage =
                                '${status.name} failed: ${status.errorMessage}';
                          }
                        });
                      }
                    },
                  );
                  // Caching finished (success or stopped on failure)
                  if (mounted && dialogContext.mounted) {
                    setDialogState(() {
                      isCaching = false;
                      cachingComplete = true;
                    });

                    // Auto-close dialog after 1.5 seconds and show snackbar
                    Future.delayed(Duration(milliseconds: 1500), () async {
                      try {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext, rootNavigator: true)
                              .pop();
                        }
                      } catch (e) {
                        print('[HomePage] Error closing cache dialog: $e');
                      }

                      // Mark firm as cached
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('auto_cached_firm_$syncId', true);
                        print('[HomePage] Marked firm $syncId as auto-cached');
                      } catch (e) {
                        print('[HomePage] Error marking firm cached: $e');
                      }

                      final bool allSuccess =
                          cacheItems.every((item) => item.isSuccess);
                      AppSnackBar.showGetXCustomSnackBar(
                        message: allSuccess
                            ? 'All data cached successfully! You can now work offline.'
                            : failureMessage ??
                                'Caching failed. Please check your internet connection and try again.',
                        backgroundColor: allSuccess ? Colors.green : Colors.red,
                      );

                      // ✅ Show battery optimization dialog AFTER offline caching dialog closes
                      // But skip if punchInOut is disabled
                      await Future.delayed(Duration(milliseconds: 500));
                      final isPunchEnabled = _isPunchInOutEnabled();
                      if (isPunchEnabled) {
                        _checkAndShowBatteryOptimizationDialog();
                      } else {
                        print(
                            '[HomePage] punchInOut is disabled - skipping battery and location dialogs');
                      }
                    });
                  }
                } catch (e) {
                  print('Error during offline caching: $e');
                  if (mounted && dialogContext.mounted) {
                    setDialogState(() {
                      isCaching = false;
                      cachingComplete = true;
                      failureMessage = 'Error: ${e.toString()}';
                    });

                    // Auto-close dialog after 2 seconds for errors too
                    Future.delayed(Duration(seconds: 2), () async {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();

                        // Still mark as cached even on error to not repeat attempts
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('auto_cached_firm_$syncId', true);

                        AppSnackBar.showGetXCustomSnackBar(
                          message: failureMessage ?? 'Offline caching failed',
                          backgroundColor: Colors.red,
                        );
                      }
                    });
                  }
                }
              });
            }

            return AlertDialog(
              title: Text('Preparing Offline Data'),
              contentPadding: EdgeInsets.all(16),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCaching && !cachingComplete)
                        Text(
                          'Setting up offline access with your latest data...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (isCaching || cachingComplete) ...[
                        SizedBox(height: 12),
                        ...cacheItems
                            .map((item) => _buildCacheItemRow(item))
                            .toList(),
                        if (failureMessage != null) ...[
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    failureMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [], // No manual action buttons - caching starts and closes automatically
            );
          },
        );
      },
    );
  }

  /// Show offline caching dialog with progress
  void _showOfflineCachingDialog() {
    bool isCaching = false;
    bool cachingComplete = false;
    List<CacheItemStatus> cacheItems = [];
    String? failureMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cloud_download, color: Color(0xFF2c9ed9)),
                  SizedBox(width: 8),
                  Text('Go Offline'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCaching && !cachingComplete)
                      Text(
                        'Download all masters for offline use?',
                        style: TextStyle(fontSize: 14),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCaching
                                ? 'Caching data...'
                                : (failureMessage != null
                                    ? 'Caching failed!'
                                    : 'Caching complete!'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: (!isCaching && failureMessage != null)
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          SizedBox(height: 16),
                          ...cacheItems.map((item) => _buildCacheItemRow(item)),
                          if (failureMessage != null) ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      failureMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                if (!isCaching && !cachingComplete)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('CANCEL'),
                  ),
                if (!isCaching && !cachingComplete)
                  ElevatedButton(
                    onPressed: () async {
                      // Initialize cache items
                      cacheItems = [
                        CacheItemStatus(name: 'Profile'),
                        CacheItemStatus(name: 'Departments'),
                        CacheItemStatus(name: 'Products'),
                        CacheItemStatus(name: 'Party'),
                        CacheItemStatus(name: 'Cart'),
                      ];
                      failureMessage = null;
                      cachingComplete = false;

                      setDialogState(() {
                        isCaching = true;
                      });

                      try {
                        await OfflineCachingService.cacheAllDataForOffline(
                          context,
                          onProgress: (status) {
                            if (mounted) {
                              setDialogState(() {
                                // Find and update the matching item
                                final index = cacheItems.indexWhere(
                                    (item) => item.name == status.name);
                                if (index != -1) {
                                  cacheItems[index] = status;
                                }

                                // Check for failure
                                if (!status.isSuccess && status.isComplete) {
                                  failureMessage =
                                      '${status.name} failed: ${status.errorMessage}';
                                }
                              });
                            }
                          },
                        );
                        // Caching finished (success or stopped on failure)
                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                            cachingComplete = true;
                          });
                        }
                      } catch (e) {
                        print('Error during offline caching: $e');
                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                            cachingComplete = true;
                            failureMessage = 'Error: ${e.toString()}';
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2c9ed9),
                    ),
                    child: Text(
                      'START',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (cachingComplete)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      final bool allSuccess =
                          cacheItems.every((item) => item.isSuccess);
                      AppSnackBar.showGetXCustomSnackBar(
                        message: allSuccess
                            ? 'All data cached successfully! You can now work offline.'
                            : failureMessage ??
                                'Caching failed. Please check your internet connection and try again.',
                        backgroundColor: allSuccess ? Colors.green : Colors.red,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2c9ed9),
                    ),
                    child: Text(
                      'DONE',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build a single cache item row with status icon and progress bar
  Widget _buildCacheItemRow(CacheItemStatus item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon - three states: waiting, in-progress, complete
              SizedBox(
                width: 24,
                height: 24,
                child: item.isComplete
                    ? (item.isSuccess
                        ? Icon(Icons.check_circle,
                            color: Colors.green, size: 24)
                        : Icon(Icons.cancel, color: Colors.red, size: 24))
                    : (item.isInProgress
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2c9ed9)),
                            ),
                          )
                        : Icon(Icons.schedule,
                            color: Colors.grey, size: 24)), // Waiting icon
              ),
              SizedBox(width: 12),
              // Item name
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Percentage/Status text
              Text(
                item.isComplete
                    ? (item.isSuccess ? '100%' : 'Failed')
                    : (item.isInProgress ? 'Loading...' : 'Waiting'),
                style: TextStyle(
                  fontSize: 12,
                  color: item.isComplete
                      ? (item.isSuccess ? Colors.green : Colors.red)
                      : (item.isInProgress ? Color(0xFF2c9ed9) : Colors.grey),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.isComplete ? 1.0 : (item.isInProgress ? 0.5 : 0.0),
              minHeight: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.isComplete
                    ? (item.isSuccess ? Colors.green : Colors.red)
                    : (item.isInProgress ? Color(0xFF2c9ed9) : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateProgressPercent(double current, double target) {
    if (target <= 0) return 0.0;
    return (current / target) * 100;
  }

  Widget _buildOverflowProgressBar(
    double percent, {
    Color baseColor = const Color(0XFF2c9ed9),
    Color overflowColor = const Color(0xFFFFC107),
    double height = 6,
  }) {
    final double baseProgress = (percent / 100).clamp(0.0, 1.0);
    final bool hasOverflow = percent > 100;

    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double overflowWidth =
              hasOverflow ? (constraints.maxWidth * 0.08).clamp(10.0, 30.0) : 0;

          return SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.grey.shade300),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: baseProgress,
                  child: Container(color: baseColor),
                ),
                if (hasOverflow)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: overflowWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: overflowColor,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(50),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Check if battery optimization is enabled and show dialog once per session
  /// This is called AFTER offline caching dialog closes
  Future<void> _checkAndShowBatteryOptimizationDialog() async {
    try {
      print('[HomePage] ===== BATTERY DIALOG CHECK STARTED =====');
      final shouldShow = await BatteryOptimizationService.shouldShowDialog();
      print(
          '[HomePage] BatteryOptimizationService.shouldShowDialog() returned: $shouldShow');
      print('[HomePage] mounted=$mounted');

      if (shouldShow && mounted) {
        print(
            '[HomePage] Battery optimization is ENABLED - showing dialog after cache dialog');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BatteryOptimizationDialog(),
        );
        print('[HomePage] Battery dialog closed by user');
        // Mark dialog as shown only after user closes it
        BatteryOptimizationService.markDialogAsShown();
        // Now check and show location permission dialog
        await _checkAndShowLocationPermissionDialog();
        await showBatteryGuideIfNeeded();
      } else {
        print(
            '[HomePage] Battery optimization check: shouldShow=$shouldShow, mounted=$mounted - dialog NOT shown');
        // Still check location permission even if battery dialog wasn't shown
        await _checkAndShowLocationPermissionDialog();
        await showBatteryGuideIfNeeded();
      }
    } catch (e) {
      print('[HomePage] Error checking battery optimization: $e');
    }
  }

  Future<void> _checkAndShowLocationPermissionDialog() async {
    try {
      print('[HomePage] ===== LOCATION PERMISSION DIALOG CHECK STARTED =====');
      final hasPermission =
          await LocationPermissionService.hasBackgroundLocationPermission();
      print(
          '[HomePage] LocationPermissionService.hasBackgroundLocationPermission() returned: $hasPermission');
      print('[HomePage] mounted=$mounted');

      // Show dialog if permission is not granted (no session flag - check every time)
      if (!hasPermission && mounted) {
        print('[HomePage] Location permission not granted - showing dialog');
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LocationPermissionDialog(),
        );
        print('[HomePage] Location permission dialog closed by user');
      } else if (hasPermission) {
        print(
            '[HomePage] Location permission already granted - dialog NOT shown');
      } else {
        print('[HomePage] Not mounted - dialog NOT shown');
      }
    } catch (e) {
      print('[HomePage] Error checking location permission: $e');
    }
  }

  /// Check if punchInOut feature is enabled in profile settings
  bool _isPunchInOutEnabled() {
    try {
      // ✅ Guard: Check if widget is still mounted before accessing context
      if (!mounted) {
        print(
            '[HomePage] _isPunchInOutEnabled: Widget not mounted, returning default');
        return true; // Default to true if widget disposed
      }

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final isPunchEnabled = profileProvider.data?.profileSettings.any(
            (e) => e.variable == 'punchInOut' && e.value == 'Y',
          ) ??
          false;
      return isPunchEnabled;
    } catch (e) {
      print('[HomePage] Error checking punchInOut setting: $e');
      return true; // Default to true to show dialogs if there's an error
    }
  }
}

extension StringCasingExtension on String {
  String toTitleCase() {
    if (isEmpty) return this; // If the string is empty, return it as is.

    return split(' ').map((word) {
      if (word.isNotEmpty) {
        // If the word contains a hyphen, split by the hyphen, capitalize each part, and join them back
        if (word.contains('-')) {
          return word
              .split('-')
              .map((part) => part.isNotEmpty
                  ? '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}'
                  : '')
              .join('-');
        } else {
          return word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : ''; // Check to avoid accessing an empty word.
        }
      } else {
        return ''; // Handle empty words (multiple spaces).
      }
    }).join(' ');
  }
}

// extension StringCasingExtension on String {
//   String toTitleCase() {
//     if (isEmpty) return this;
//     return split(' ').map((word) {
//       if (word.isNotEmpty) {
//         // If the word contains a hyphen, split by the hyphen, capitalize each part, and join them back
//         if (word.contains('-')) {
//           return word
//               .split('-')
//               .map((part) =>
//                   '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
//               .join('-');
//         } else {
//           return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
//         }
//       } else {
//         return ''; // Handle empty words (multiple spaces)
//       }
//     }).join(' ');
//   }
// }
