import 'dart:io';

import 'package:arham_corporation/models/orderlistModal.dart';
import 'package:arham_corporation/models/ordermodal.dart';
import 'package:arham_corporation/providers/bill_provider.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/providers/order_fetch_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/person_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/splashScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'constants/constants.dart';

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(statusBarColor: Color(0XFF2c9ed9)));

  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(MyApp());
  });

  Directory directory = await getApplicationDocumentsDirectory();
  Hive.initFlutter();
  Hive.init(directory.path);
  Hive.registerAdapter(OrdermodalAdapter());
  Hive.registerAdapter(OrderItmAdapter());
  Hive.registerAdapter(DatumOrderListAdapter());
  Hive.registerAdapter(DataOrdritmAdapter());
  await Hive.openBox<Ordermodal>(Constants.addOrder);
  await Hive.openBox<DatumOrderList>(Constants.orderFetch);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Global>(create: (context) => Global()),
        ChangeNotifierProvider<UserProvider>(
            create: (context) => UserProvider()),
        ChangeNotifierProvider<LocationProvider>(
            create: (context) => LocationProvider()),
        ChangeNotifierProvider<PartyProvider>(
            create: (context) => PartyProvider()),
        ChangeNotifierProvider<CartListProvider>(
            create: (context) => CartListProvider()),
        ChangeNotifierProvider<OrderFetchProvider>(
            create: (context) => OrderFetchProvider()),
        ChangeNotifierProvider<ItemListProvider>(
            create: (context) => ItemListProvider()),
        ChangeNotifierProvider<PersonProvider>(
            create: (context) => PersonProvider()),
        ChangeNotifierProvider<ProfileProvider>(
            create: (context) => ProfileProvider()),
        ChangeNotifierProvider<BillProvider>(
            create: (context) => BillProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return GetMaterialApp(
            title: 'Arham OMS',
            theme: ThemeData(
                appBarTheme: AppBarTheme(
                  elevation: 0,
                  backgroundColor: Color(0XFF2c9ed9),
                ),
                visualDensity: VisualDensity.adaptivePlatformDensity,
                fontFamily: GoogleFonts.roboto().fontFamily),
            debugShowCheckedModeBanner: false,
            home: child,
          );
        },
        child: SplashScreen(),
      ),
    );
  }
}
