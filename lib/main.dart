import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:arham_corporation/models/orderlistModal.dart';
import 'package:arham_corporation/models/ordermodal.dart';
import 'package:arham_corporation/providers/bill_provider.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/children_provider.dart';
import 'package:arham_corporation/providers/global.dart';
import 'package:arham_corporation/providers/item_list_provider.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/providers/order_fetch_provider.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/person_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/background_location_service.dart';
import 'package:arham_corporation/services/connectivity_service.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/heartbeat_workmanager.dart';
import 'package:arham_corporation/services/location_tracking_workmanager.dart';
import 'package:arham_corporation/views/item_wise_sale/providers/item_list_provider.dart'
    as item_wise_sale_provider;
import 'package:arham_corporation/views/splashScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:arham_corporation/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'constants/constants.dart';

Future<void>? _initFuture;

Future<void> initializeAppServices() {
  if (_initFuture != null) return _initFuture!;
  _initFuture = _initializeAppServicesInternal();
  return _initFuture!;
}

Future<void> _initializeAppServicesInternal() async {
  final String platformName = Platform.isIOS
      ? 'iOS'
      : (Platform.isAndroid ? 'Android' : Platform.operatingSystem);
  print('[Main] 📱 Platform: $platformName');
  print('[Main] 🚀 Asynchronous app services initialization started...');

  // 1. Initialize Firebase Core with options & 6s timeout
  try {
    print('[Main] 📡 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 6));
    print('[Main] ✅ Firebase initialized successfully');
  } catch (e) {
    print('[Main] ❌ Firebase initialization failed or timed out: $e');
  }

  // 2. Set up Error/Crashlytics Handlers
  try {
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
    print('[Main] ✅ Error and Crashlytics handlers registered');
  } catch (e) {
    print('[Main] ⚠️ Error setting up error handlers: $e');
  }

  // 3. Initialize Hive with self-healing recovery
  try {
    final directory = await getApplicationDocumentsDirectory();
    print('[Main] 📂 App documents directory: ${directory.path}');
    print('[Main] 🗄️ Initializing Hive...');
    await Hive.initFlutter();
    print('[Main] ✅ Hive.initFlutter() completed');

    Hive.registerAdapter(OrdermodalAdapter());
    Hive.registerAdapter(OrderItmAdapter());
    Hive.registerAdapter(DatumOrderListAdapter());
    Hive.registerAdapter(DataOrdritmAdapter());
    print('[Main] ✅ Hive adapters registered');

    // Open Constants.addOrder with self-healing
    try {
      await Hive.openBox<Ordermodal>(Constants.addOrder);
      print('[Main] ✅ Hive box opened: ${Constants.addOrder}');
    } catch (e) {
      print('[Main] ⚠️ Error opening Hive box ${Constants.addOrder}, attempting recovery...');
      try {
        await Hive.deleteBoxFromDisk(Constants.addOrder);
        await Hive.openBox<Ordermodal>(Constants.addOrder);
        print('[Main] ✅ Hive box recovered and opened: ${Constants.addOrder}');
      } catch (recoveryError) {
        print('[Main] ❌ Failed to recover Hive box ${Constants.addOrder}: $recoveryError');
      }
    }

    // Open Constants.orderFetch with self-healing
    try {
      await Hive.openBox<DatumOrderList>(Constants.orderFetch);
      print('[Main] ✅ Hive box opened: ${Constants.orderFetch}');
    } catch (e) {
      print('[Main] ⚠️ Error opening Hive box ${Constants.orderFetch}, attempting recovery...');
      try {
        await Hive.deleteBoxFromDisk(Constants.orderFetch);
        await Hive.openBox<DatumOrderList>(Constants.orderFetch);
        print('[Main] ✅ Hive box recovered and opened: ${Constants.orderFetch}');
      } catch (recoveryError) {
        print('[Main] ❌ Failed to recover Hive box ${Constants.orderFetch}: $recoveryError');
      }
    }

    print('[Main] ✅ All Hive boxes opened successfully');
  } catch (e, stack) {
    print('[Main] ❌ Hive initialization error: $e');
    print('[Main] ❌ Hive stack: $stack');
    try {
      unawaited(CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'hive_initialization_failed_$platformName',
      ));
    } catch (_) {}
  }

  // 4. Pre-warm SQLite Database (non-blocking)
  try {
    print('[Main] 🗄️ Warming up SQLite database...');
    await DatabaseHelper().database;
    print('[Main] ✅ SQLite database warm-up completed');
  } catch (e, stack) {
    print('[Main] ⚠️ SQLite database warm-up failed (non-fatal): $e');
    try {
      unawaited(CrashlyticsService.recordNonFatal(
        e,
        stack,
        reason: 'sqlite_warmup_failed_$platformName',
      ));
    } catch (_) {}
  }

  // 5. Preferred orientation
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    print('[Main] ✅ Preferred orientations set');
  } catch (e) {
    print('[Main] ⚠️ Preferred orientations setup failed: $e');
  }
}

void main() {
  runZonedGuarded(() async {
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Color(0XFF2c9ed9)));

    WidgetsFlutterBinding.ensureInitialized();

    // Start services initialization immediately in the background
    unawaited(initializeAppServices());

    // Run MyApp immediately so the first frame isn't blocked on services init
    runApp(const MyApp());
  }, (error, stack) {
    print('[runZonedGuarded] Uncaught startup error: $error');
    print(stack);
    try {
      unawaited(CrashlyticsService.recordFatal(
        error,
        stack,
        reason: 'run_zoned_guarded_uncaught',
      ));
    } catch (_) {}
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
        ChangeNotifierProvider<ChildrenProvider>(
          create: (_) => ChildrenProvider(),
        ),
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
