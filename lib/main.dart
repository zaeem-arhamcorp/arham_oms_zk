import 'dart:async';
import 'dart:io';
import 'dart:ui';

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
import 'package:arham_corporation/services/connectivity_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/views/item_wise_sale/providers/item_list_provider.dart'
    as item_wise_sale_provider;
import 'package:arham_corporation/views/splashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'constants/constants.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(statusBarColor: Color(0XFF2c9ed9)));

  WidgetsFlutterBinding.ensureInitialized();

  // Minimal local error handler until Crashlytics is available
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Render UI immediately so first frame is not blocked
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    // Log synchronously; Crashlytics will be wired later if available
    print('[runZonedGuarded] $error');
    print(stack);
  });

  // Initialize Firebase & heavy services asynchronously with a short timeout
  Future.microtask(() async {
    try {
      // Short timeout to avoid permanent startup freeze on iOS
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));

      // Now wire Crashlytics and platform error forwarding
      FlutterError.onError = (errorDetails) {
        FlutterError.presentError(errorDetails);
        unawaited(CrashlyticsService.recordFlutterFatal(
          errorDetails,
          reason: 'flutter_framework_uncaught',
        ));
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(CrashlyticsService.recordFatal(
          error,
          stack,
          reason: 'platform_dispatcher_uncaught',
        ));
        return true;
      };

      print('[Main] ✅ Firebase initialized');
    } catch (e, stack) {
      print('[Main] ❌ Firebase init failed or timed out: $e');
      print(stack);
      try {
        unawaited(CrashlyticsService.recordNonFatal(
          e,
          stack,
          reason: 'firebase_init_failed',
        ));
      } catch (_) {}
    }

    // Initialize local storage and DB asynchronously (non-blocking)
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      await Hive.initFlutter();
      Hive.init(directory.path);
      Hive.registerAdapter(OrdermodalAdapter());
      Hive.registerAdapter(OrderItmAdapter());
      Hive.registerAdapter(DatumOrderListAdapter());
      Hive.registerAdapter(DataOrdritmAdapter());
      await Hive.openBox<Ordermodal>(Constants.addOrder);
      await Hive.openBox<DatumOrderList>(Constants.orderFetch);
      unawaited(DatabaseHelper().database);
      print('[Main] ✅ Local storage initialized (async)');
    } catch (e, stack) {
      print('[Main] ⚠️ Local storage init failed: $e');
      try {
        unawaited(CrashlyticsService.recordNonFatal(
          e,
          stack,
          reason: 'local_storage_init_failed',
        ));
      } catch (_) {}
    }

    // Defer heavy background service initializations until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('[Main] Initializing post-frame services...');
        // ConnectivityService requires a BuildContext; initialization happens in MyApp
        // Keep background services / workmanager init commented or guarded for iOS
        // await BackgroundLocationService().initialize();
        // await Workmanager().initialize(locationTrackingCallbackDispatcher);
        print('[Main] ✅ Post-frame services initialized');
      } catch (e, stack) {
        print('[Main] ⚠️ Post-frame services init failed: $e');
      }
    });
  });
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
        ChangeNotifierProvider<item_wise_sale_provider.ItemListProvider>(
            create: (context) => item_wise_sale_provider.ItemListProvider()),
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
          // Initialize connectivity & background service
          WidgetsBinding.instance.addPostFrameCallback((_) {
            print('[MyApp] Initializing services after first frame...');
            // Initialize connectivity with a BuildContext here (available in MyApp)
            ConnectivityService().initialize(context);
            print('[MyApp] ✅ ConnectivityService initialized');
          });

          return GetMaterialApp(
            title: 'Arham OMS',
            routingCallback: (routing) {
              final currentScreen = routing?.current;
              if (currentScreen != null && currentScreen.isNotEmpty) {
                unawaited(CrashlyticsService.setScreenName(currentScreen));
              }
            },
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
