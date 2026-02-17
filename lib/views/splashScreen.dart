import 'package:flutter/material.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/widgets/ErrorPage.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/intropage.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

    getUtlity().then((_) {
      if (ub.isSignedIn == true) {
        context.read<ProfileProvider>().getProfile(context).then((value) {
          context.read<PartyProvider>().getpartyname(context);
          context.read<ItemListProvider>().getItems(context);
          if (isCurrentVersion == true) {
            print('bottam page');
            Get.offAll(() => BottomnavigationBarScreen());
          } else {
            print('update page 1');
            Get.offAll(() => UpdatePageScreen());
          }
        });
      } else if (isError == true) {
        Get.offAll(() => ErrorPageScreen());
      } else {
        if (isCurrentVersion == true) {
          print('intro page');
          Get.offAll(() => IntroPage());
        } else {
          print('update page');
          Get.offAll(() => UpdatePageScreen());
        }
      }
    });
  }

  getUtlity() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    await Services().getUtlity(context).then((value) {
      setState(() {
        if (value != null) {
          if (isIOS()) {
            if (Helper.getExtendedVersionNumber(value.data.iosAppVersion.toString()) <=
                Helper.getExtendedVersionNumber(packageInfo.version.toString())) {
              isCurrentVersion = true;
            } else {
              isCurrentVersion = false;
            }
          } else if (isAndroid()) {
            if (Helper.getExtendedVersionNumber(value.data.androidAppVersion.toString()) <=
                Helper.getExtendedVersionNumber(packageInfo.version.toString())) {
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
                  padding: const EdgeInsets.only(bottom: 25.0, left: 18.0, right: 18.0),
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
