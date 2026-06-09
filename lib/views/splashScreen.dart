import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/intropage.dart';
import 'package:arham_corporation/widgets/ErrorPage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../helper/network_helper.dart';
import '../providers/item_list_provider.dart';
import '../providers/party_provider.dart';
import '../services/services.dart';
import '../widgets/bottomnavebar.dart';
import '../widgets/platform_helper.dart';
import '../widgets/updatePageScreen.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isCurrentVersion = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _afterSplash();
  }

  Future<void> _afterSplash() async {
    // Ensure all background/core initializations (Firebase, Hive) have completed
    print('[SplashScreen] 🔄 Waiting for main app services initialization...');
    await initializeAppServices();
    print('[SplashScreen] ✅ Main app services initialization completed');

    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // ✅ CRITICAL: Initialize UserProvider BEFORE any logic
    print('[SplashScreen] 🔄 Initializing UserProvider...');
    await ub.initializeAsync();
    print('[SplashScreen] ✅ UserProvider initialized');

    // ✅ TOKEN VALIDATION: If no token, force logout
    if (ub.token == null || ub.token!.isEmpty) {
      print('[SplashScreen] ⚠️ No token found - redirecting to login');
      Get.offAll(() => IntroPage());
      return;
    }

    // Use the platform helper to check if the platform is Android or iOS
    if (isAndroid()) {
      Helper().checkVersion();
      Helper().checkPermission();
    }

    // First check connectivity with a short timeout so splash never hangs.
    // Handle timeout properly - if timeout, treat as offline
    try {
      final bool online =
          await NetworkHelper.hasInternet().timeout(const Duration(seconds: 4));
      await _handleSplashNavigation(online, ub);
    } catch (e) {
      // If connectivity check times out or fails, treat as OFFLINE
      print(
          '[SplashScreen] ⚠️ Connectivity check failed: $e - Treating as offline');
      await _handleSplashNavigation(false, ub);
    }
  }

  Future<void> _handleSplashNavigation(bool online, UserProvider ub) async {
    try {
      if (!online) {
        // ===== OFFLINE PATH =====
        print('[SplashScreen] 🔴 OFFLINE - Loading from cache');
        if (ub.isSignedIn == true) {
          try {
            // Try to populate profile from cache
            print('[SplashScreen] Loading profile from cache...');
            await context
                .read<ProfileProvider>()
                .getProfile()
                .timeout(const Duration(seconds: 3));

            final profileProvider = context.read<ProfileProvider>();
            if (profileProvider.isProfileLoaded) {
              print('[SplashScreen] ✅ Profile loaded from cache');
            } else {
              print(
                  '[SplashScreen] ⚠️ Profile not loaded - will use offline defaults');
            }

            // Load settings from cache
            try {
              await context
                  .read<ProfileProvider>()
                  .loadSettings(context)
                  .timeout(const Duration(seconds: 2));
              print('[SplashScreen] ✅ Settings loaded from cache');
            } catch (e) {
              print('[SplashScreen] ⚠️ Settings load timed out: $e');
            }
          } catch (e) {
            print('[SplashScreen] ⚠️ Profile load failed (offline): $e');
          }

          // Try to load parties from cache
          try {
            await context
                .read<PartyProvider>()
                .getpartyname(context)
                .timeout(const Duration(seconds: 2));
            print('[SplashScreen] ✅ Parties loaded from cache');
          } catch (e) {
            print('[SplashScreen] ⚠️ Parties load failed: $e');
          }

          // Try to load items from cache
          try {
            await context
                .read<ItemListProvider>()
                .getItems(context)
                .timeout(const Duration(seconds: 2));
            print('[SplashScreen] ✅ Items loaded from cache');
          } catch (e) {
            print('[SplashScreen] ⚠️ Items load failed: $e');
          }

          print('[SplashScreen] 🚀 Navigating to HomePage (offline mode)');
          Get.offAll(() => BottomnavigationBarScreen());
        } else {
          print('[SplashScreen] 🚀 Navigating to IntroPage (not signed in)');
          Get.offAll(() => IntroPage());
        }
        return;
      }

      // ===== ONLINE PATH =====
      print('[SplashScreen] 🟢 ONLINE - Fetching from server');
      try {
        await getUtlity().timeout(const Duration(seconds: 5));
      } catch (e) {
        print('[SplashScreen] getUtility failed: $e');
      }

      if (ub.isSignedIn == true) {
        print('[SplashScreen] Loading profile from server...');
        try {
          await context
              .read<ProfileProvider>()
              .getProfile()
              .timeout(const Duration(seconds: 6));

          final profileProvider = context.read<ProfileProvider>();
          if (profileProvider.isProfileLoaded) {
            print('[SplashScreen] ✅ Profile loaded from server');
          } else {
            print('[SplashScreen] ⚠️ Profile load incomplete');
          }

          // Load settings
          try {
            await context
                .read<ProfileProvider>()
                .loadSettings(context)
                .timeout(const Duration(seconds: 5));
            print('[SplashScreen] ✅ Settings loaded from server');
          } catch (e) {
            print('[SplashScreen] ⚠️ Settings load failed: $e');
          }
        } catch (e) {
          print('[SplashScreen] ⚠️ Profile load failed: $e');
        }

        // Fire-and-forget other initial fetches
        try {
          context.read<PartyProvider>().getpartyname(context);
          context.read<ItemListProvider>().getItems(context);
        } catch (_) {}

        if (isCurrentVersion == true) {
          print('[SplashScreen] 🚀 Navigating to HomePage');
          Get.offAll(() => BottomnavigationBarScreen());
        } else {
          print('[SplashScreen] 🚀 Navigating to UpdatePage');
          Get.offAll(() => UpdatePageScreen());
        }
      } else if (isError == true) {
        print('[SplashScreen] 🚀 Navigating to ErrorPage');
        Get.offAll(() => ErrorPageScreen());
      } else {
        if (isCurrentVersion == true) {
          print('[SplashScreen] 🚀 Navigating to IntroPage');
          Get.offAll(() => IntroPage());
        } else {
          print('[SplashScreen] 🚀 Navigating to UpdatePage');
          Get.offAll(() => UpdatePageScreen());
        }
      }
    } catch (e) {
      print('[SplashScreen] ❌ Unexpected error in navigation: $e');
      if (ub.isSignedIn == true) {
        Get.offAll(() => BottomnavigationBarScreen());
      } else {
        Get.offAll(() => IntroPage());
      }
    }
  }

  Future<void> getUtlity() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      // When offline, avoid calling remote utility endpoint and keep defaults
      setState(() {
        // Keep isCurrentVersion true by default so intro/login is reachable
        isCurrentVersion = true;
      });
      return;
    }

    await Services().getUtlity(context).then((value) {
      setState(() {
        if (value != null) {
          if (isIOS()) {
            if (Helper.getExtendedVersionNumber(
                    value.data.iosAppVersion.toString()) <=
                Helper.getExtendedVersionNumber(
                    packageInfo.version.toString())) {
              isCurrentVersion = true;
            } else {
              isCurrentVersion = false;
            }
          } else if (isAndroid()) {
            if (Helper.getExtendedVersionNumber(
                    value.data.androidAppVersion.toString()) <=
                Helper.getExtendedVersionNumber(
                    packageInfo.version.toString())) {
              isCurrentVersion = true;
            } else {
              isCurrentVersion = false;
            }
          }
        } else {
          isError = true;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Image.asset('assets/arhamOMS_icon.png')),
              SizedBox(
                width: double.infinity,
                height: 80.0,
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 25.0, left: 18.0, right: 18.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
