import 'dart:io';

import 'package:arham_corporation/helper/notification_services.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/views/party_managment/bindings/account_bindings.dart';
import 'package:arham_corporation/views/party_managment/screens/edit_account_screen.dart';
import 'package:arham_corporation/views/route_schedule_plan/controllers/beat_controller.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class Helper {
  static bool canAddParty(ProfileProvider? profileProvider) {
    final profile = profileProvider?.data;
    if (profile == null || profile.modulesList == null) {
      return false;
    }

    return profile.modulesList!.any(
      (module) => module.mODULENO == '102' && module.wRITERIGHT == true,
    );
  }

  static bool canEditParty(ProfileProvider? profileProvider) {
    final profile = profileProvider?.data;
    if (profile == null || profile.modulesList == null) {
      return false;
    }

    return profile.modulesList!.any(
      (module) => module.mODULENO == '102' && module.uPDATERIGHT == true,
    );
  }

  static String maskMobileNumber(String mobile) {
    if (mobile.length < 6) return mobile; // safety check

    final firstTwo = mobile.substring(0, 2);
    final lastFour = mobile.substring(mobile.length - 4);

    return '$firstTwo****$lastFour';
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  static final possibleFormats = [
    'dd-MM-yyyy',
    'yyyy-MM-dd',
    'dd/MM/yyyy',
    'yyyy/MM/dd',
    'dd.MM.yyyy',
    'yyyy.MM.dd',
    'dd/MMM/yyyy',
    'yyyy/MMM/dd',
    'dd-MMM-yyyy',
    'yyyy-MMM-dd',
    'dd MMM yyyy',
    'yyyy MMM dd',
    'yyyy-MM-ddTHH:mm:ss',
    'yyyy-MM-ddTHH:mm:ssZ',
    'yyyy-MM-ddTHH:mm:ss.SSS',
    'yyyy-MM-ddTHH:mm:ss.SSSZ',
    'yyyy-MM-ddTHH:mm:ss.SSSSSS',
    'dd-MM-yyyy HH:mm',
    'dd-MM-yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss',
    'yyyy-MM-dd HH:mm:ss',
    'yyyy/MM/dd HH:mm:ss',
    'dd-MM-yyyy hh:mm a',
    'dd/MM/yyyy hh:mm a',
    'yyyy-MM-dd hh:mm a',
    'ddMMyyyy',
    'yyyyMMdd',
    'ddMMyy',
    'yyMMdd',
  ];

  static DateTime? parseAnyDate(String inputDate) {
    for (var f in possibleFormats) {
      try {
        return DateFormat(f).parseStrict(inputDate);
      } catch (_) {}
    }
    try {
      return DateTime.parse(inputDate);
    } catch (_) {}
    return null;
  }

  static String toUi(String date) {
    final parsed = parseAnyDate(date);
    if (parsed == null) return date;
    return DateFormat("dd-MM-yyyy").format(parsed);
  }

  static String toApi(String date) {
    final parsed = parseAnyDate(date);
    if (parsed == null) return date;
    return DateFormat("yyyy-MM-dd").format(parsed);
  }

  static String convertToFormat(String inputDate, String outputFormat) {
    final possibleFormats = [
      // Basic numeric formats
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'dd.MM.yyyy',
      'yyyy.MM.dd',

      // Month names
      'dd/MMM/yyyy',
      'yyyy/MMM/dd',
      'dd-MMM-yyyy',
      'yyyy-MMM-dd',
      'dd MMM yyyy',
      'yyyy MMM dd',

      // ISO formats
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-ddTHH:mm:ssZ',
      'yyyy-MM-ddTHH:mm:ss.SSS',
      'yyyy-MM-ddTHH:mm:ss.SSSZ',
      'yyyy-MM-ddTHH:mm:ss.SSSSSS',

      // Date + time formats
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm:ss',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy/MM/dd HH:mm:ss',

      // 12-hour clock formats
      'dd-MM-yyyy hh:mm a',
      'dd/MM/yyyy hh:mm a',
      'yyyy-MM-dd hh:mm a',

      // Compact formats (no separators)
      'ddMMyyyy',
      'yyyyMMdd',
      'ddMMyy',
      'yyMMdd',
    ];

    for (var format in possibleFormats) {
      try {
        final date = DateFormat(format).parseStrict(inputDate);
        return DateFormat(outputFormat).format(date);
      } catch (_) {}
    }

    return inputDate; // fallback
  }

  static String trimValue(String str, length) {
    return str.length > length ? "${str.substring(0, length)}..." : str;
  }

  static String getDefaultFromDate() {
    return DateTime.now().month == 1 ||
            DateTime.now().month == 2 ||
            DateTime.now().month == 3
        ? "${DateTime.now().year - 1}-04-01"
        : "${DateTime.now().year}-04-01";
  }

  static String parseNumericValue(String? str) {
    var format = NumberFormat.currency(locale: 'HI');
    return str != null && str != 'null' && str != "."
        ? format.format(double.parse(str)).replaceFirst("INR", "")
        : "";
  }

  static Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      if (result == PermissionStatus.granted) {
        return true;
      }
    }
    return false;
  }

  // fileExtensionType - pdf, xlsx
  static Future<String?> saveFileAndroid(
      String url, String reportName, String successMsg) async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    int androidVersion = 10;
    AndroidDeviceInfo d = await deviceInfo.androidInfo;
    androidVersion = int.parse(d.version.release.split('.')[0]);

    try {
      late final NotificationService notificationService;
      notificationService = NotificationService();
      void listenToNotificationStream() =>
          notificationService.behaviorSubject.listen((payload) async {});
      listenToNotificationStream();
      notificationService.initializePlatformNotifications();

      File saveFileUrl = File("");
      if (await _requestPermission(androidVersion.isGreaterThan(11)
          ? Permission.mediaLibrary
          : Permission.storage)) {
        Directory? directory;
        directory = Platform.isIOS
            ? await getApplicationDocumentsDirectory()
            //: await Directory("/storage/emulated/0/Download");
            : Directory("/storage/emulated/0/Download");
        String newPath = "";
        List<String> paths = directory.path.split("/");
        for (int x = 1; x < paths.length; x++) {
          String folder = paths[x];
          if (folder != "Android") {
            newPath += "/$folder";
          } else {
            break;
          }
        }
        newPath = "$newPath/ArhamErp";
        directory = Directory(newPath);

        saveFileUrl =
            File("${directory.path}/$reportName.${url.split(".").last}");
        if (kDebugMode) {
          print(saveFileUrl.path);
        }
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        if (await directory.exists()) {
          await Dio()
              .download(
            url,
            saveFileUrl.path,
          )
              .then((value) async {
            // Fluttertoast.showToast(
            //     msg: successMsg, toastLength: Toast.LENGTH_LONG);
            AppSnackBar.showGetXCustomSnackBar(
                message: successMsg, backgroundColor: Colors.green);
          });

          await notificationService.showLocalNotification(
              id: DateTime.now().toString().length,
              title: "Report Downloaded",
              body: "File Downloaded in ${saveFileUrl.path} ",
              payload: saveFileUrl.path);
        }
      } else {
        // Fluttertoast.showToast(
        //     msg: "Please provide storage Permission from the settings.",
        //     toastLength: Toast.LENGTH_LONG);
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Please provide storage Permission from the settings.');
      }
      return saveFileUrl.path;
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      return null;
    }
  }

  static Future<String?> saveFileIOS(
      String url, String reportName, String successMsg) async {
    try {
      final notificationService = NotificationService();
      notificationService.initializePlatformNotifications();
      notificationService.behaviorSubject.listen((payload) async {
        // handle payload if needed
      });

      File saveFileUrl = File("");

      // Check platform and handle storage accordingly
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int androidVersion =
            int.parse(androidInfo.version.release.split('.')[0]);

        if (await _requestPermission(
          androidVersion > 11 ? Permission.mediaLibrary : Permission.storage,
        )) {
          Directory directory =
              Directory("/storage/emulated/0/Download/ArhamErp");

          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          saveFileUrl =
              File("${directory.path}/$reportName.${url.split(".").last}");

          await Dio().download(url, saveFileUrl.path);

          AppSnackBar.showGetXCustomSnackBar(
            message: successMsg,
            backgroundColor: Colors.green,
          );

          await notificationService.showLocalNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: "Report Downloaded",
            body: "File downloaded in ${saveFileUrl.path}",
            payload: saveFileUrl.path,
          );
        } else {
          AppSnackBar.showGetXCustomSnackBar(
            message: 'Please provide storage permission from the settings.',
          );
        }
      } else if (Platform.isIOS) {
        // iOS: Save to app's document directory
        Directory directory = await getApplicationDocumentsDirectory();

        saveFileUrl =
            File("${directory.path}/$reportName.${url.split(".").last}");

        await Dio().download(url, saveFileUrl.path);

        AppSnackBar.showGetXCustomSnackBar(
          message: successMsg,
          backgroundColor: Colors.green,
        );

        await notificationService.showLocalNotification(
          id: DateTime.now().millisecondsSinceEpoch,
          title: "Report Downloaded",
          body: "File downloaded in ${saveFileUrl.path}",
          payload: saveFileUrl.path,
        );
      }

      return saveFileUrl.path;
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      return null;
    }
  }

  static List buildSearchList(String userSearchTerm, PartyProvider party) {
    List searchList = [];

    for (int i = 0; i < party.data.length; i++) {
      String name = party.data[i].accName;
      String personName = party.data[i].person_nm?.toString() ?? "";
      String mobileNo = party.data[i].mobile;
      String accCd = party.data[i].accCd;
      String cartItem = party.data[i].accCartItem;
      String? add1 = party.data[i].add1;
      String? add2 = party.data[i].add2;
      String? add3 = party.data[i].add3;
      String? city = party.data[i].city;
      String? zone = party.data[i].zone;
      if (userSearchTerm.startsWith("*")) {
        if (name.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            personName.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            mobileNo.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            accCd.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            cartItem.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            add1!.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            add2!.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            add3!.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            city!.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase()) ||
            zone!.toLowerCase().contains(
                userSearchTerm.replaceRange(0, 1, "").toLowerCase())) {
          searchList.add(party.data[i]);
        }
      } else {
        if (name.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
            personName.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
            mobileNo.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
            accCd.toLowerCase().contains(userSearchTerm.toLowerCase()) ||
            cartItem.toLowerCase().contains(userSearchTerm.toLowerCase())) {
          searchList.add(party.data[i]);
        }
      }
    }
    return searchList;
  }

  static Widget showPartyBottomSheetWithSearch(int index, List listOfParty,
      {bool showEditButton = false}) {
    // 🛡️ Bounds check: Prevent RangeError when index is out of bounds
    if (index < 0 || index >= listOfParty.length) {
      print(
          '[Helper] ⚠️ Index out of bounds: index=$index, listLength=${listOfParty.length}');
      return ListTile(
        leading: Text("${index + 1}"),
        title: const Text("Item not found"),
        dense: true,
      );
    }

    // Format last order days into readable text
    final lastOrderDaysValue = listOfParty[index].lastOrderDays;
    String lastOrderText = '';
    if (lastOrderDaysValue != null) {
      final daysAgo = lastOrderDaysValue;
      if (daysAgo == null) {
        lastOrderText = 'No previous order';
      }
      if (daysAgo == 0) {
        lastOrderText = 'Last order: Today';
      } else if (daysAgo == 1) {
        lastOrderText = 'Last order: Yesterday';
      } else if (daysAgo > 1) {
        lastOrderText = 'Last order: $daysAgo days ago';
      } else {
        lastOrderText = 'No previous order';
      }
    }

    // Get beat information if party has beatCd
    String beatName = '';
    final beatCd = listOfParty[index].beatCd;
    if (beatCd != null && beatCd.toString().trim().isNotEmpty) {
      try {
        final beatController = Get.find<BeatController>();
        final beatList = beatController.beats;
        final beat = beatList.firstWhereOrNull(
          (b) => b.beatCd.toLowerCase() == beatCd.toString().toLowerCase(),
        );
        if (beat != null) {
          beatName = beat.beatName;
        }
      } catch (e) {
        // BeatController not found, skip beat display
        print('[Helper] Beat info not available: $e');
      }
    }

    return ListTile(
      leading: Text("${index + 1}"),
      trailing: showEditButton
          ? IconButton(
              onPressed: () async {
                final accountData = _toAccountDataMap(listOfParty[index]);
                final result = await Get.to<bool>(
                  () => EditAccountScreen(accountData: accountData),
                  binding: AccountBindings(),
                );

                if (result == true) {
                  final context = Get.context;
                  if (context != null) {
                    try {
                      await Provider.of<PartyProvider>(context, listen: false)
                          .getPartyNameProductPage(context);
                    } catch (e) {
                      print(
                          '[Helper] Failed to refresh party list after edit: $e');
                    }
                  }
                }
              },
              icon: Icon(Icons.edit),
            )
          : null,
      title: Text(
          //"(${listOfParty[index].accCd}) ${listOfParty[index].accName} ${listOfParty[index].person_nm != null ? " - " + listOfParty[index].person_nm : ""}",
          "(${listOfParty[index].accCd}) "
          "${listOfParty[index].accName}"
          "${listOfParty[index].person_nm != null ? " - ${listOfParty[index].person_nm}" : ""} "
          "||"
          "${listOfParty[index].clBAL != null ? " CL BAL : ${formatAmount(double.parse(listOfParty[index].clBAL.toString()))}" : ""}",
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
      subtitle: RichText(
        text: TextSpan(
          text:
              "${listOfParty[index].accAddress} || ${listOfParty[index].mobile}",
          style: TextStyle(color: Colors.black),
          children: [
            if (listOfParty[index].accCartItem != null)
              TextSpan(
                text: " || ${listOfParty[index].accCartItem}",
                style: TextStyle(color: Colors.amber),
              ),
            if (beatName.isNotEmpty)
              TextSpan(
                text: "Beat: $beatName",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            TextSpan(
              text: "\n$lastOrderText",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      dense: true,
    );
  }

  static Map<String, dynamic> _toAccountDataMap(dynamic party) {
    if (party is Map<String, dynamic>) {
      return party;
    }

    String beatCd = '';
    try {
      beatCd = (party.beatCd ?? '').toString();
    } catch (_) {
      beatCd = '';
    }

    return {
      'ACC_CD': party.accCd ?? '',
      'ACC_NAME': party.accName ?? '',
      'BEAT_CD': beatCd,
      'PERSON_NM': party.person_nm ?? '',
      'MOBILE1': party.mobile ?? '',
      'ADD1': party.add1 ?? '',
      'ZONE': party.zone ?? '',
      'CITY': party.city ?? '',
      'STATE': party.state ?? '',
      'PINCODE': party.pincode ?? '',
      'LATITUDE': party.lat ?? 0,
      'LONGITUDE': party.long ?? 0,
      'GST_NO': party.gstNo ?? '',
      'GST_TYPE': party.gstType ?? '',
      'DRUG_LIC1': party.drugLic1 ?? '',
      'DRUG_LIC2': party.drugLic2 ?? '',
      'FSSAI_NO': party.fssaiNo ?? '',
      'EMAIL': party.email ?? '',
      'PAN_NO': party.panNo ?? '',
      'CREDIT_DAY': party.creditDay ?? 0,
      'CR_LIMIT': party.crLimit ?? 0,
      'CL_BAL': party.clBAL ?? 0,
      'ACC_ADD': party.accAddress ?? '',
      'ACC_CART_ITEM': party.accCartItem ?? '',
      'LAST_ORDER_DAYS_AGO': party.lastOrderDays ?? 0,
    };
  }

  static String formatAmount(double amount) {
    final formatter =
        NumberFormat('#,##0.00', 'en_US'); // Format with commas and 2 decimals
    return formatter.format(amount);
  }

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  int androidVersion = 10;

  Future<void> checkPermission() async {
    var a = await (Permission.storage.isGranted);
    var b = await (Permission.manageExternalStorage.isGranted);
    var c = await (Permission.mediaLibrary.isGranted);
    if (androidVersion.isGreaterThan(11)) {
      a = true;
    }
    if (androidVersion.isLowerThan(10)) {
      b = true;
      c = true;
    }

    if ((a == false) || (b == false) || (c == false)) {
      handelStoragePermission();
    } else {
      ////premission grant
    }
  }

  Future<void> checkVersion() async {
    AndroidDeviceInfo d = await deviceInfo.androidInfo;
    androidVersion = int.parse(d.version.release.toString());
  }

  Future<void> handelStoragePermission() async {
    var isGreaterAndroid = androidVersion.isGreaterThan(11) ? true : false;

    Map<Permission, PermissionStatus> result = await [
      if (isGreaterAndroid == false) Permission.storage,
      Permission.manageExternalStorage,
      Permission.mediaLibrary,
      Permission.photos,
      Permission.videos,
    ].request();
    if (isGreaterAndroid == false) {
      result[Permission.storage] == PermissionStatus.granted;

      ///grantPermission
    } else if (result[Permission.manageExternalStorage] ==
            PermissionStatus.granted &&
        result[Permission.mediaLibrary] == PermissionStatus.granted &&
        result[Permission.photos] == PermissionStatus.granted &&
        result[Permission.videos] == PermissionStatus.granted) {
      ////Permission grant
    } else {
      Get.showSnackbar(GetSnackBar(
        title: "Error",
        message: "Storage Permission is Required",
        snackPosition: SnackPosition.TOP,
        duration: Duration(milliseconds: 1000),
      ));
    }
  }

  static int getExtendedVersionNumber(String version) {
    List versionCells = version.split('.');
    versionCells = versionCells.map((i) => int.parse(i)).toList();
    return versionCells[0] * 100000 + versionCells[1] * 1000 + versionCells[2];
  }
}
