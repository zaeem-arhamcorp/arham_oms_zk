//
// import 'dart:io';
// import 'dart:math';
//
// import 'package:arham_corporation/product/widget/app_snack_bar.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:dio/dio.dart';
// //import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// //import 'package:fluttertoast/fluttertoast.dart';
// import 'package:arham_corporation/helper/helper.dart';
//
// import 'package:share_plus/share_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
//
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
//
// import '../config/app_config.dart';
// import '../helper/notification_services.dart';
// import 'package:get/get.dart';
//
// class PdfViewerScreen extends StatefulWidget {
//   final String pdfUrl;
//   final String fileName;
//   const PdfViewerScreen(
//       {Key? key, required this.pdfUrl, required this.fileName})
//       : super(key: key);
//
//   @override
//   State<PdfViewerScreen> createState() => _PdfViewerScreenState();
// }
//
// class _PdfViewerScreenState extends State<PdfViewerScreen> {
//   bool showLoading = false;
//   FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   final PathProviderPlatform provider = PathProviderPlatform.instance;
//   late final NotificationService notificationService;
//
//   @override
//   void initState() {
//     notificationService = NotificationService();
//     listenToNotificationStream();
//     notificationService.initializePlatformNotifications();
//     super.initState();
//   }
//
//   void listenToNotificationStream() =>
//       notificationService.behaviorSubject.listen((payload) async {});
//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Pdf Viewer"),
//         actions: [
//           IconButton(
//             onPressed: () {
//               _pdfShare();
//             },
//             icon: Icon(Icons.share),
//           ),
//           IconButton(
//             onPressed: () async {
//               if(Platform.isAndroid){
//                 setState(() {
//                   showLoading = true;
//                 });
//
//                 // saveFile(widget.pdfUrl, widget.fileName).then((value) => {
//                 //   setState(() {
//                 //     showLoading = false;
//                 //   })
//                 // });
//
//                 Helper.saveFile(widget.pdfUrl, widget.fileName,
//                     "Pdf File has been downloaded")
//                     .then((value) => {
//                   setState(() {
//                     showLoading = false;
//                   })
//                 });
//
//                 // _pdfDownloade();
//               }else if(Platform.isIOS){
//                 setState(() {
//                   showLoading = true;
//                 });
//
//                 // saveFile(widget.pdfUrl, widget.fileName).then((value) => {
//                 //   setState(() {
//                 //     showLoading = false;
//                 //   })
//                 // });
//
//                 Helper.saveFile1(widget.pdfUrl, widget.fileName,
//                     "Pdf File has been downloaded")
//                     .then((value) => {
//                   setState(() {
//                     showLoading = false;
//                   })
//                 });
//
//                 // _pdfDownloade();
//               }
//             },
//             icon: Icon(Icons.download),
//           ),
//         ],
//       ),
//       body: Container(
//         height: size.height,
//         width: size.width,
//         child: Stack(
//           children: [
//             SfPdfViewer.network(widget.pdfUrl),
//             Visibility(
//               visible: showLoading,
//               child: Container(
//                 height: size.height,
//                 width: size.width,
//                 color: Colors.grey.withOpacity(0.6),
//                 child: Center(
//                     child: CircularProgressIndicator(
//                   color: AppConfig.mainColor,
//                 )),
//               ),
//             )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<bool> saveFile(String url, String fileName) async {
//     try {
//       setState(() {
//         showLoading = true;
//       });
//       if (await _requestPermission(Permission.mediaLibrary)) {
//         Random random = new Random();
//         int randomNumber = random.nextInt(100000);
//         print("pppppppppp");
//         Directory? directory;
//         directory = Platform.isIOS
//             ? await getApplicationDocumentsDirectory()
//             //: await DownloadsPathProvider.downloadsDirectory;
//             : await Directory('/storage/emulated/0/Download');;
//         print(directory);
//         String newPath = "";
//         List<String> paths = directory.path.split("/");
//         for (int x = 1; x < paths.length; x++) {
//           String folder = paths[x];
//           if (folder != "Android") {
//             newPath += "/" + folder;
//           } else {
//             break;
//           }
//         }
//         newPath = Platform.isAndroid
//             ? newPath + "/FusionCrop/${widget.fileName}"
//             : newPath + "/${widget.fileName}";
//         directory = Directory(newPath);
//
//         File saveFile =
//             File(directory.path + "/$fileName" "${randomNumber}.pdf");
//         if (kDebugMode) {
//           print(saveFile.path);
//         }
//         if (!await directory.exists()) {
//           await directory.create(recursive: true);
//         }
//         if (await directory.exists()) {
//           await Dio()
//               .download(
//             url,
//             saveFile.path,
//           )
//               .then((value) async {
//             await notificationService.showLocalNotification(
//                 id: randomNumber,
//                 title: "${widget.fileName}.pdf",
//                 body: "File Downloaded in ${saveFile.path} ",
//                 payload: "${saveFile.path}");
//           });
//         }
//         setState(() {
//           showLoading = false;
//         });
//         AppSnackBar.showGetXCustomSnackBar(
//             message: "Pdf Downloaded to FusionCrop Directory",backgroundColor: Colors.green);
//       }
//       return true;
//     } catch (e, stack) {
//       setState(() {
//         showLoading = false;
//       });
//       return false;
//     }
//   }
//
//   Future<bool> _requestPermission(Permission permission) async {
//     if (await permission.isGranted) {
//       return true;
//     } else {
//       var result = await permission.request();
//       if (result == PermissionStatus.granted) {
//         return true;
//       }
//     }
//     return false;
//   }
//
//   // ignore: unused_element
//   _pdfShare1() async {
//     DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     int androidVersion = 10;
//     AndroidDeviceInfo d = await deviceInfo.androidInfo;
//     androidVersion = int.parse(d.version.release.split('.')[0]);
//     setState(() {
//       showLoading = true;
//     });
//     List<String> save = [];
//     Map<Permission, PermissionStatus> statuses = await [
//       androidVersion.isGreaterThan(11)
//           ? Permission.mediaLibrary
//           : Permission.storage
//       //add more permission to request here.
//     ].request();
//     if (statuses[androidVersion.isGreaterThan(11)
//             ? Permission.mediaLibrary
//             : Permission.storage]!
//         .isGranted) {
//       var dir = (await getTemporaryDirectory()).path;
//       String savename =
//           "/${widget.fileName}.${widget.pdfUrl.split(".").last}";
//       String savePath = dir + "/$savename";
//       save.add(savePath);
//       try {
//         await Dio().download(widget.pdfUrl, savePath,
//             onReceiveProgress: (received, total) {
//           print(received);
//           if (total != -1) {
//             print((received / total * 100).toStringAsFixed(0) + "%");
//             //you can build progressbar feature too
//           }
//         }).then((value) async {
//           await SharePlus.instance.share(
//             files: [XFile(savePath)],
//             text: "Here's your PDF: ${widget.fileName}",
//           );
//
//           setState(() {
//             showLoading = false;
//           });
//         });
//       } on DioError catch (e) {
//         print(e.message);
//         setState(() {
//           showLoading = false;
//         });
//       }
//     } else {
//       //Fluttertoast.showToast(msg: "No permission to read and write.");
//       AppSnackBar.showGetXCustomSnackBar(message: "No permission to read and write.");
//       print("No permission to read and write.");
//       setState(() {
//         showLoading = false;
//       });
//     }
//   }
//
//   _pdfShare() async {
//     DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//     int androidVersion = 10;
//     if (Platform.isAndroid) {
//       AndroidDeviceInfo d = await deviceInfo.androidInfo;
//       androidVersion = int.parse(d.version.release.split('.')[0]);
//     }
//
//     setState(() {
//       showLoading = true;
//     });
//
//     try {
//       if (Platform.isAndroid) {
//         Map<Permission, PermissionStatus> statuses = await [
//           androidVersion > 11 ? Permission.mediaLibrary : Permission.storage
//         ].request();
//
//         if (!statuses[androidVersion > 11 ? Permission.mediaLibrary : Permission.storage]!.isGranted) {
//           AppSnackBar.showGetXCustomSnackBar(message: "No permission to read and write.");
//           setState(() {
//             showLoading = false;
//           });
//           return;
//         }
//       }
//
//       Directory dir = await getTemporaryDirectory();
//       String savePath = "${dir.path}/${widget.fileName}.${widget.pdfUrl.split(".").last}";
//
//       // Download PDF
//       await Dio().download(widget.pdfUrl, savePath, onReceiveProgress: (received, total) {
//         if (total != -1) {
//           print((received / total * 100).toStringAsFixed(0) + "%");
//         }
//       });
//
//       final file = File(savePath);
//       print("File exists: ${await file.exists()}");
//       print("File size: ${await file.length()} bytes");
//
//       // Share PDF with the new API
//       await SharePlus.instance.share(
//         files: [XFile(savePath)],
//         text: "Here's your PDF: ${widget.fileName}",
//       );
//
//       setState(() {
//         showLoading = false;
//       });
//     } catch (e, stack) {
//       print("Error: $e");
//       AppSnackBar.showGetXCustomSnackBar(message: "PDF sharing failed");
//       setState(() {
//         showLoading = false;
//       });
//     }
//   }
//
// }
import 'dart:io';
import 'dart:math';

import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../config/app_config.dart';
import '../helper/notification_services.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String fileName;

  const PdfViewerScreen(
      {Key? key, required this.pdfUrl, required this.fileName})
      : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool showLoading = false;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final PathProviderPlatform provider = PathProviderPlatform.instance;
  late final NotificationService notificationService;

  @override
  void initState() {
    super.initState();
    notificationService = NotificationService();
    listenToNotificationStream();
    notificationService.initializePlatformNotifications();
  }

  void listenToNotificationStream() =>
      notificationService.behaviorSubject.listen((payload) async {
        // Handle payload from notification tap if needed
      });

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Pdf Viewer",
        actions: [
          IconButton(
            onPressed: _pdfShare,
            icon: Icon(Icons.share),
          ),
          IconButton(
            onPressed: () async {
              setState(() {
                showLoading = true;
              });
              // Using your custom Helper function
              if (Platform.isIOS) {
                Helper.saveFileIOS(widget.pdfUrl, widget.fileName,
                        "Pdf File has been downloaded")
                    .whenComplete(() => setState(() => showLoading = false));
              } else {
                Helper.saveFileAndroid(widget.pdfUrl, widget.fileName,
                        "Pdf File has been downloaded")
                    .whenComplete(() => setState(() => showLoading = false));
              }
            },
            icon: Icon(Icons.download),
          ),
        ],
      ),
      body: Container(
        height: size.height,
        width: size.width,
        child: Stack(
          children: [
            SfPdfViewer.network(widget.pdfUrl),
            if (showLoading)
              Container(
                height: size.height,
                width: size.width,
                color: Colors.grey.withOpacity(0.6),
                child: Center(
                    child: CircularProgressIndicator(
                  color: AppConfig.mainColor,
                )),
              ),
          ],
        ),
      ),
    );
  }

  /// Shares the PDF by downloading it to a temporary directory first.
  Future<void> _pdfShare() async {
    setState(() {
      showLoading = true;
    });

    try {
      // On modern Android, permissions may not be needed to share from app's temp directory.
      // However, requesting is safer for older versions.

      // if (Platform.isAndroid) {
      //   final androidInfo = await DeviceInfoPlugin().androidInfo;
      //   if (androidInfo.version.sdkInt < 33) {
      //     final status = await Permission.storage.request();
      //     if (!status.isGranted) {
      //       AppSnackBar.showGetXCustomSnackBar(
      //           message: "Storage permission is required to share files.");
      //       setState(() => showLoading = false);
      //       return;
      //     }
      //   }
      // }

      final Directory dir = await getTemporaryDirectory();
      // Ensure the file extension is correctly handled, defaulting to .pdf
      final String fileExtension =
          widget.pdfUrl.contains('.') ? widget.pdfUrl.split('.').last : 'pdf';
      final String savePath = "${dir.path}/${widget.fileName}.$fileExtension";

      // Download the file
      await Dio().download(widget.pdfUrl, savePath);

      // --- CORRECTED API CALL ---
      // Use the static method on the 'Share' class, not 'SharePlus'.
      await Share.shareXFiles(
        [XFile(savePath)],
        text: "Here's your PDF: ${widget.fileName}",
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      if (kDebugMode) {
        print("Error sharing PDF: $e");
      }
      AppSnackBar.showGetXCustomSnackBar(message: "PDF sharing failed.");
    } finally {
      // Ensure the loading indicator is always hidden
      if (mounted) {
        setState(() {
          showLoading = false;
        });
      }
    }
  }

  // This is a sample save file implementation. You are using Helper.saveFile instead.
  // I've kept it here in case you need it, but it is currently unused.
  Future<bool> saveFile(String url, String fileName) async {
    try {
      setState(() {
        showLoading = true;
      });
      if (await _requestPermission(Permission.storage)) {
        Random random = new Random();
        int randomNumber = random.nextInt(100000);
        Directory? directory;
        if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          // Saving to a custom public directory. Be aware of Scoped Storage on Android 10+.
          directory = Directory('/storage/emulated/0/FusionCrop');
        }

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final savePath = "${directory.path}/$fileName-${randomNumber}.pdf";
        File saveFile = File(savePath);

        if (kDebugMode) {
          print(saveFile.path);
        }

        await Dio().download(url, saveFile.path).then((value) async {
          await notificationService.showLocalNotification(
              id: randomNumber,
              title: "${widget.fileName}.pdf",
              body: "File Downloaded in ${saveFile.path} ",
              payload: saveFile.path);
        });

        AppSnackBar.showGetXCustomSnackBar(
            message: "Pdf Downloaded to FusionCrop Directory",
            backgroundColor: Colors.green);
        return true;
      }
      return false;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          showLoading = false;
        });
      }
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
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
}
