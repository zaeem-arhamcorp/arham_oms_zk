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
import 'package:arham_corporation/views/item_wise_sale/providers/item_list_provider.dart'
    as item_wise_sale_provider;
import 'package:arham_corporation/views/splashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'constants/constants.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/connectivity_service.dart';
import 'package:arham_corporation/services/background_location_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/location_tracking_workmanager.dart';
import 'package:arham_corporation/services/heartbeat_workmanager.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  runZonedGuarded(() async {
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Color(0XFF2c9ed9)));

    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();

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

    // ✅ Initialize Hive BEFORE building widgets
    Directory directory = await getApplicationDocumentsDirectory();
    Hive.initFlutter();
    Hive.init(directory.path);
    Hive.registerAdapter(OrdermodalAdapter());
    Hive.registerAdapter(OrderItmAdapter());
    Hive.registerAdapter(DatumOrderListAdapter());
    Hive.registerAdapter(DataOrdritmAdapter());
    await Hive.openBox<Ordermodal>(Constants.addOrder);
    await Hive.openBox<DatumOrderList>(Constants.orderFetch);

    // ✅ Initialize SQLite database BEFORE building widgets
    await DatabaseHelper().database;

    // ✅ Initialize background location service BEFORE building widgets
    print('[Main] Initializing background location service...');
    await BackgroundLocationService().initialize();
    print('[Main] ✅ Background location service initialized');

    // ✅ Initialize periodic recovery for app-kill scenarios (no boot recovery)
    print('[Main] Initializing Workmanager core...');
    try {
      await Workmanager().initialize(
        locationTrackingCallbackDispatcher,
        isInDebugMode: false,
      );
      print('[Main] ✅ Workmanager core initialized');
    } catch (e, stack) {
      print('[Main] ⚠️ Workmanager init warning: $e');
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'workmanager_init_warning',
      );
    }

    print('[Main] Initializing location tracking WorkManager...');
    await LocationTrackingWorkmanager.initialize();
    await LocationTrackingWorkmanager.registerPeriodicRecoveryTask();
    await LocationTrackingWorkmanager.logLastWorkerHeartbeat();
    print('[Main] ✅ Location tracking WorkManager initialized');

    // ✅ Initialize heartbeat workmanager BEFORE building widgets
    print('[Main] Initializing heartbeat WorkManager...');
    await HeartbeatWorkmanager.initialize();
    await HeartbeatWorkmanager.registerPeriodicHeartbeatTask();
    await HeartbeatWorkmanager.logHeartbeatWorkerHeartbeat();
    print('[Main] ✅ Heartbeat WorkManager initialized');

    // ✅ Attempt immediate resume if app was killed with active tracking
    print('[Main] Checking for active trip to resume...');
    try {
      final resumed =
          await BackgroundLocationService().resumeTrackingIfActiveTrip();
      if (resumed) {
        print('[Main] ✅ Active trip resumed on app startup');
      } else {
        print('[Main] ℹ️ No active trip to resume');
      }
    } catch (e, stack) {
      print('[Main] ⚠️ Error resuming active trip: $e');
      await CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'resume_active_trip_failed',
      );
    }

    // ✅ NOW set orientation and build app (all initialization done)
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const MyApp());
  }, (error, stack) {
    unawaited(CrashlyticsService.recordFatal(
      error,
      stack,
      reason: 'run_zoned_guarded_uncaught',
    ));
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
