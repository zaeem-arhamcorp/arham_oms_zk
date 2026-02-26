import 'package:arham_corporation/product/ui/product_page.dart';
import 'package:arham_corporation/views/company_management/newmenu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/views/homepage.dart';
import 'package:arham_corporation/views/profilePage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_provider.dart';
import '../views/dailyReportScreen.dart';

class BottomnavigationBarScreen extends StatefulWidget {
  const BottomnavigationBarScreen({Key? key}) : super(key: key);

  @override
  State<BottomnavigationBarScreen> createState() => _BottomnavigationBarScreenState();
}

class _BottomnavigationBarScreenState extends State<BottomnavigationBarScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _buildPages(ProfileProvider p) {
    List<Widget> pages = [
      HomePage(),
      NewMenu(),
    ];
    if (p.data?.modulesList != null &&
        p.data!.modulesList!.any((module) =>
        module.mODULENO == "301" &&
            (module.rEADRIGHT == true || module.pRINTRIGHT == true))) {
      pages.add(DailyReportScreen());
    }
    pages.add(ProductsPage());
    pages.add(ProfilePage());
    return pages;
  }

  List<BottomNavigationBarItem> _buildBottomNavigationItems(ProfileProvider p) {
    List<BottomNavigationBarItem> items = [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.widgets_outlined), label: 'Menus'),
    ];
    if (p.data != null && p.data!.modulesList!.any((module) => module.mODULENO == "301" &&
        (module.rEADRIGHT == true || module.pRINTRIGHT == true))) {
      items.add(BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'));
    }
    items.add(BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Order'));
    items.add(BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider ub = context.watch<UserProvider>();
    final LocationProvider l = context.watch<LocationProvider>();
    final ProfileProvider p = context.watch<ProfileProvider>();

    final List<Widget> pages = _buildPages(p);
    final List<BottomNavigationBarItem> bottomNavItems = _buildBottomNavigationItems(p);

    // Safeguard for invalid _selectedIndex
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // ✅ Important: this fixes bottom nav above keyboard
      body: StreamBuilder<ServiceStatus>(
        stream: Geolocator.getServiceStatusStream(),
        builder: (context, snapshot) {
          if (snapshot.data == ServiceStatus.enabled) {
            l.changeLocationStatus(true);
          }

          bool locationEnabled = snapshot.data == ServiceStatus.enabled || l.enebleLocationPermission == true;

          if (ub.role == AppConfig.operatoruser && !locationEnabled) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Location Is Required",
                    style: TextStyle(fontSize: 20.sp),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      LocationPermission permission = await Geolocator.checkPermission();
                      bool isServiceEnabled = await Geolocator.isLocationServiceEnabled();
                      if (isServiceEnabled) {
                        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                          await Geolocator.openAppSettings();
                        } else {
                          l.changeLocationStatus(true);
                        }
                      } else {
                        await Geolocator.openLocationSettings();
                      }
                    },
                    child: Text("Enable Location"),
                  ),
                ],
              ),
            );
          } else {
            return Scaffold(
              backgroundColor: Colors.white,
              resizeToAvoidBottomInset: true,
              body: pages[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                //backgroundColor: Color(0xFFE2E2E2),
                backgroundColor: Colors.white,
                showUnselectedLabels: true,
                currentIndex: _selectedIndex,
                items: bottomNavItems,
                onTap: _onItemTapped,
              ),
            );
          }
        },
      ),
    );
  }
}
