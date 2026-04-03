import 'package:flutter/material.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/widgets/ErrorPage.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/intropage.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../helper/network_helper.dart';
import 'package:provider/provider.dart';

import '../providers/item_list_provider.dart';
import '../providers/party_provider.dart';
import '../services/services.dart';
import '../widgets/bottomnavebar.dart';
import '../widgets/platform_helper.dart';
import '../widgets/updatePageScreen.dart';

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

  _afterSplash() {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Use the platform helper to check if the platform is Android or iOS
    if (isAndroid()) {
      Helper().checkVersion();
      Helper().checkPermission();
    }

    // First check connectivity with a short timeout so splash never hangs.
    Future<bool> onlineCheck = NetworkHelper.hasInternet();
    onlineCheck.timeout(const Duration(seconds: 4)).then((online) async {
      if (!online) {
        // If signed in, attempt to load cached profile/parties/items
        // so the app can continue after being killed/backgrounded.
        if (ub.isSignedIn == true) {
          try {
            // Try to populate profile from cache (provider already handles offline load)
            await context
                .read<ProfileProvider>()
                .getProfile()
                .timeout(const Duration(seconds: 2));

            // Load settings (cached or from API)
            await context
                .read<ProfileProvider>()
                .loadSettings(context)
                .timeout(const Duration(seconds: 2));
          } catch (e) {
            print('Loading cached profile or settings timed out or failed: $e');
          }

          try {
            await context
                .read<PartyProvider>()
                .getpartyname(context)
                .timeout(const Duration(seconds: 2));
          } catch (e) {
            print('Loading cached parties timed out or failed: $e');
          }

          try {
            await context
                .read<ItemListProvider>()
                .getItems(context)
                .timeout(const Duration(seconds: 2));
          } catch (e) {
            print('Loading cached items timed out or failed: $e');
          }

          Get.offAll(() => BottomnavigationBarScreen());
          return;
        }

        if (isCurrentVersion == true) {
          Get.offAll(() => IntroPage());
        } else {
          Get.offAll(() => UpdatePageScreen());
        }
        return;
      }

      // Online: perform normal utility & profile fetch flow but guard with timeouts
      try {
        await getUtlity().timeout(const Duration(seconds: 5));
      } catch (e) {
        // If utility fetch times out or fails, continue with caution
        print('getUtlity failed or timed out: $e');
      }

      try {
        if (ub.isSignedIn == true) {
          // Ensure profile fetch doesn't hang the splash screen
          try {
            await context
                .read<ProfileProvider>()
                .getProfile()
                .timeout(const Duration(seconds: 6));

            // Load settings (cached or from API)
            await context
                .read<ProfileProvider>()
                .loadSettings(context)
                .timeout(const Duration(seconds: 5));
          } catch (e) {
            print('Profile fetch or settings load failed or timed out: $e');
          }

          // Fire-and-forget other initial fetches (do not await long-running calls)
          try {
            context.read<PartyProvider>().getpartyname(context);
            context.read<ItemListProvider>().getItems(context);
          } catch (_) {}

          if (isCurrentVersion == true) {
            Get.offAll(() => BottomnavigationBarScreen());
          } else {
            Get.offAll(() => UpdatePageScreen());
          }
        } else if (isError == true) {
          Get.offAll(() => ErrorPageScreen());
        } else {
          if (isCurrentVersion == true) {
            Get.offAll(() => IntroPage());
          } else {
            Get.offAll(() => UpdatePageScreen());
          }
        }
      } catch (e) {
        print('Unexpected error in splash navigation: $e');
        // Final fallback: navigate to intro so user can continue offline
        if (ub.isSignedIn == true) {
          Get.offAll(() => BottomnavigationBarScreen());
        } else {
          Get.offAll(() => IntroPage());
        }
      }
    }).catchError((err) {
      // If connectivity check itself errors or times out, fallback to cached decision
      print('Connectivity check failed or timed out: $err');
      if (ub.isSignedIn == true) {
        Get.offAll(() => BottomnavigationBarScreen());
      } else {
        if (isCurrentVersion == true) {
          Get.offAll(() => IntroPage());
        } else {
          Get.offAll(() => UpdatePageScreen());
        }
      }
    });
  }

  getUtlity() async {
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
              Expanded(child: Image.asset('assets/intro_img.png')),
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
