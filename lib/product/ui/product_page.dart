import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/product/widget/product_card.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/party_managment/services/api_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/partynameModal.dart';
import '../../models/productModal.dart';
import '../../providers/cart_list_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/database_helper.dart';
import '../../services/services.dart';
import '../../views/party_managment/bindings/account_bindings.dart';
import '../../views/party_managment/screens/add_account_screen.dart';
import '../../widgets/pdfViewerScreen.dart';
import '../controller/cart_controller.dart';
import '../controller/product_controller.dart';
import '../model/selfie_dialog_taglines.dart';
import '../widget/app_bar.dart';
import '../widget/chip_widget.dart';

final Rx<File?> selfieFile = Rx<File?>(null);
final RxBool isSelfieUploading = false.obs;
final RxString selfieDialogQuote = ''.obs;
final ImagePicker selfiePicker = ImagePicker();

Future<void> _fetchSelfieDialogQuote() async {
  try {
    String? token;
    try {
      final context = Get.context;
      if (context != null) {
        token = Provider.of<UserProvider>(context, listen: false).token;
      }
    } catch (_) {
      token = null;
    }

    final quoteUrl = Uri.parse('${AppConfig.baseURL}trip/quoteForSelfie');
    final response = await http.get(
      quoteUrl,
      headers: {
        'x-app-type': 'oms',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 8));

    print(quoteUrl);
    print(response);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final quote = (decoded['data'] ?? '').toString().trim();
        if (quote.isNotEmpty) {
          selfieDialogQuote.value = quote;
          return;
        }
      }
    }

    selfieDialogQuote.value = '';
  } catch (e) {
    selfieDialogQuote.value = '';
    print('[SELFIE-DIALOG] quoteForSelfie fetch failed: $e');
  }
}

Future<bool> _checkSelfieUploadedToday() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final todayStr = Helper.toApi(today.toString());
  final selfieDate = prefs.getString('selfie_uploaded_date');
  return selfieDate == todayStr;
}

Future<void> _setSelfieUploadedToday() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final todayStr = Helper.toApi(today.toString());
  await prefs.setString('selfie_uploaded_date', todayStr);
}

Future<File?> _pickSelfieFromCamera() async {
  try {
    final picked = await selfiePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90);
    if (picked == null) return null;

    // Convert XFile to File
    final pickedFile = File(picked.path);
    final originalSize = await pickedFile.length();
    print(
        '[SELFIE-COMPRESSION] Original image size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

    // Compress to under 1MB
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      picked.path + '_compressed.jpg',
      quality: 85,
      minWidth: 600,
      minHeight: 800,
    );
    if (compressed != null) {
      final compressedSize = await compressed.length();
      print(
          '[SELFIE-COMPRESSION] After quality=85: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('[SELFIE-COMPRESSION] Compressed file path: ${compressed.path}');
      if (compressedSize < 1024 * 1024) {
        print(
            '[SELFIE-COMPRESSION] ✅ Size OK (${(compressedSize / 1024).toStringAsFixed(0)} KB), using quality=85 compression');
        final compressedFile = File(compressed.path);
        print(
            '[SELFIE-COMPRESSION] File exists: ${await compressedFile.exists()}');
        return compressedFile;
      } else {
        // Try again with lower quality if still >1MB
        final lower = await FlutterImageCompress.compressAndGetFile(
          picked.path,
          picked.path + '_compressed2.jpg',
          quality: 70,
          minWidth: 480,
          minHeight: 640,
        );
        if (lower != null) {
          final lowerSize = await lower.length();
          print(
              '[SELFIE-COMPRESSION] After quality=70: ${(lowerSize / 1024 / 1024).toStringAsFixed(2)} MB');
          print('[SELFIE-COMPRESSION] Compressed file path: ${lower.path}');
          if (lowerSize < 1024 * 1024) {
            print(
                '[SELFIE-COMPRESSION] ✅ Size OK (${(lowerSize / 1024).toStringAsFixed(0)} KB), using quality=70 compression');
            final lowerFile = File(lower.path);
            print(
                '[SELFIE-COMPRESSION] File exists: ${await lowerFile.exists()}');
            return lowerFile;
          }
        }
      }
    }
    print(
        '[SELFIE-COMPRESSION] ⚠️ Compression failed, using original (${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB)');
    return pickedFile;
  } catch (e) {
    print('[SELFIE-COMPRESSION] Camera error: $e');
    return null;
  }
}

Future<bool> _uploadSelfie(File selfie, String userCd) async {
  try {
    isSelfieUploading.value = true;

    // Retrieve trip ID from SharedPreferences (stored during punch-in)
    final prefs = await SharedPreferences.getInstance();
    final tripId = prefs.getInt('active_trip_id') ?? 0;

    print('[SELFIE-UPLOAD] File path: ${selfie.path}');
    print('[SELFIE-UPLOAD] Checking if file exists...');

    // Check if file exists
    final exists = await selfie.exists();
    if (!exists) {
      print('[SELFIE-UPLOAD] ❌ File does not exist at ${selfie.path}');
      isSelfieUploading.value = false;
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Image file was not saved. Please capture again.');
      return false;
    }

    final fileSize = await selfie.length();
    print(
        '[SELFIE-UPLOAD] File to upload: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB (${(fileSize / 1024).toStringAsFixed(0)} KB)');
    print('[SELFIE-UPLOAD] Uploading selfie for user=$userCd, trip_id=$tripId');
    print(
        '[SELFIE-UPLOAD] Sending headers: x-app-type=oms, fields: user_cd=$userCd, trip_id=$tripId, image=${selfie.path}');

    final api = ApiService(baseUrl: AppConfig.baseURL);
    final resp = await api.postMultipart(
      '/trip/upload-selfie',
      headers: {
        'x-app-type': 'oms',
      },
      fields: {
        'user_cd': userCd,
        if (tripId > 0) 'trip_id': tripId.toString(),
      },
      files: {'image': selfie},
    );
    isSelfieUploading.value = false;
    print('[SELFIE-UPLOAD] Response status: ${resp['statusCode']}');
    print('[SELFIE-UPLOAD] Response body: ${resp['json']}');
    if (resp['statusCode'] == 200 &&
        (resp['json']?['success'] == true || resp['json']?['status'] == true)) {
      print('[SELFIE-UPLOAD] ✅ Upload successful');
      return true;
    }
    print(
        '[SELFIE-UPLOAD] ❌ Upload failed: ${resp['json']?['message'] ?? resp['body']}');
    AppSnackBar.showGetXCustomSnackBar(
        message:
            'Selfie upload failed: ${resp['json']?['message'] ?? resp['body']}');
    return false;
  } catch (e) {
    isSelfieUploading.value = false;
    print('[SELFIE-UPLOAD] ❌ Exception: $e');
    AppSnackBar.showGetXCustomSnackBar(message: 'Selfie upload error: $e');
    return false;
  }
}

Future<bool> _showSelfieDialogAndUpload(
    ProfileProvider profile, PartyProvider party) async {
  selfieFile.value = null;
  selfieDialogQuote.value = '';
  unawaited(_fetchSelfieDialogQuote());
  bool uploadSuccess = false;

  await Get.dialog(
    Obx(() => AlertDialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          title: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    // Container(
                    //   width: 40,
                    //   height: 40,
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withOpacity(0.18),
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: const Icon(
                    //     Icons.camera_alt_outlined,
                    //     color: Colors.white,
                    //     size: 20,
                    //   ),
                    // ),
                    // const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ready for your first order ?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadiusGeometry.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          selfieDialogQuote.value.isNotEmpty
                              ? selfieDialogQuote.value
                              : getRandomSelfieDialogTagline(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          content: Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Image upload area
                  GestureDetector(
                    onTap: () async {
                      print(
                          '[SELFIE-DIALOG] onUploadTap called - picking from camera');
                      final file = await _pickSelfieFromCamera();
                      if (file != null) {
                        print('[SELFIE-DIALOG] File selected: ${file.path}');
                        print(
                            '[SELFIE-DIALOG] File exists: ${await file.exists()}');
                        selfieFile.value = file;
                        print('[SELFIE-DIALOG] selfieFile.value set');
                      } else {
                        print('[SELFIE-DIALOG] File pick returned null');
                      }
                    },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: selfieFile.value != null
                                ? Image.file(selfieFile.value!,
                                    fit: BoxFit.cover)
                                : Center(
                                    child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 5,
                                      ),
                                      const Text(
                                        'Take selfie',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ],
                                  )),
                          ),
                          if (selfieFile.value != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () {
                                  print(
                                      '[SELFIE-DIALOG] Deleting selected file');
                                  selfieFile.value = null;
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // No remarks field (intentionally omitted)

                  const SizedBox(height: 8),

                  // Loader or buttons
                  isSelfieUploading.value
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  print('[SELFIE-DIALOG] onSubmit called');
                                  if (selfieFile.value == null) {
                                    print('[SELFIE-DIALOG] No file selected');
                                    AppSnackBar.showGetXCustomSnackBar(
                                        message: 'Please capture a selfie');
                                    return;
                                  }
                                  print(
                                      '[SELFIE-DIALOG] File: ${selfieFile.value!.path}');
                                  print(
                                      '[SELFIE-DIALOG] File exists before upload: ${await selfieFile.value!.exists()}');
                                  if (isSelfieUploading.value) {
                                    print(
                                        '[SELFIE-DIALOG] Already uploading, ignoring submit');
                                    return;
                                  }
                                  final userCd = profile.userCode ?? '';
                                  if (userCd.isEmpty) {
                                    print('[SELFIE-DIALOG] User code missing');
                                    AppSnackBar.showGetXCustomSnackBar(
                                        message: 'User code missing');
                                    return;
                                  }
                                  // Verify trip is active before uploading
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final tripId =
                                      prefs.getInt('active_trip_id') ?? 0;
                                  if (tripId <= 0) {
                                    print('[SELFIE-DIALOG] No active trip');
                                    AppSnackBar.showGetXCustomSnackBar(
                                        message:
                                            'No active trip. Please punch in first.');
                                    return;
                                  }
                                  print(
                                      '[SELFIE-DIALOG] Calling _uploadSelfie...');
                                  final ok = await _uploadSelfie(
                                      selfieFile.value!, userCd);
                                  if (ok) {
                                    print('[SELFIE-DIALOG] Upload successful');
                                    await _setSelfieUploadedToday();
                                    uploadSuccess = true;
                                    Get.back();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Submit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  print('[SELFIE-DIALOG] onCancel called');
                                  Get.back();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        )),
    barrierDismissible: false,
  );
  return uploadSuccess;
}

class ProductsPage extends StatefulWidget {
  final String? initialStockistCd;

  const ProductsPage({super.key, this.initialStockistCd});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProductController controller = Get.isRegistered<ProductController>()
      ? Get.find<ProductController>()
      : Get.put(ProductController());
  final CartController cartController = Get.isRegistered<CartController>()
      ? Get.find<CartController>()
      : Get.put(CartController());

  String? deptCd;

  bool isLoading = true;
  bool _isOrderProcessing = false; // Prevent multiple clicks on order buttons
  bool _isSorting = false; // Track if party list is being sorted by distance
  List<DatumProduct> dataProduct = [];

  List<TextEditingController> qty = [];
  List<TextEditingController> rate = [];
  List<TextEditingController> freeQty = [];
  List<TextEditingController> remarks = [];

  late CartListProvider cart;

  var viewRight = false;
  var addRight = false;
  var updateRight = false;
  var deleteRight = false;
  var printRight = false;

  // Monthly target data map: stockist code -> target info for PRIMARY/POB.
  Map<String, Map<String, dynamic>> _monthlyTargetByStockist = {};

  bool get _canEditParty => Helper.canEditParty(
        Provider.of<ProfileProvider>(context, listen: false),
      );

  bool get _canAddParty => Helper.canAddParty(
        Provider.of<ProfileProvider>(context, listen: false),
      );

  /// Get fresh location via Geolocator for on-demand tracking
  bool _isContinuousLocationTrackingEnabled(ProfileProvider profile) {
    try {
      final setting = profile.data?.profileSettings.firstWhere(
        (e) => e.variable == 'continuousLocationTracking',
      );
      return (setting?.value ?? 'N') == 'Y';
    } catch (e) {
      // Setting not found, default to disabled so sorting stays off.
      return false;
    }
  }

  /// Get fresh location via Geolocator for on-demand tracking
  /// Used for START_ORDER, END_ORDER, PUNCH IN/OUT when continuous tracking disabled
  Future<Map<String, String>> _getFreshLocationForOrder(
    ProfileProvider profile,
    PartyProvider party,
    String activityType,
  ) async {
    var lat = "0";
    var long = "0";

    try {
      print(
          '[LOCATION] 📍 Fetching fresh location via Geolocator for $activityType...');

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION] ⚠️ Location permission permanently denied');
        return {'lat': '0', 'long': '0'};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      lat = position.latitude.toString();
      long = position.longitude.toString();

      // Store in on-demand table
      try {
        final partyId =
            profile.YN == "Y" ? party.punchInOutPartyId : party.partyid;
        final db = DatabaseHelper();
        await db.insertOnDemandLocation(
          partyId: partyId,
          latitude: position.latitude,
          longitude: position.longitude,
          activityType: activityType,
        );
        print(
            '[LOCATION] ✅ On-demand location stored: lat=$lat, lng=$long, activity=$activityType');
      } catch (storageErr) {
        print('[LOCATION] ⚠️ Error storing on-demand location: $storageErr');
      }
    } catch (e) {
      print(
          '[LOCATION] ⚠️ Error fetching fresh location: $e, using default (0, 0)');
    }

    return {'lat': lat, 'long': long};
  }

  /// Get location based on tracking preference for orders
  Future<Map<String, String>> _getLocationForOrder(
    ProfileProvider profile,
    PartyProvider party,
    String activityType,
  ) async {
    var lat = "0";
    var long = "0";

    try {
      final isContinuous = _isContinuousLocationTrackingEnabled(profile);
      print(
          '[LOCATION] Tracking mode: ${isContinuous ? "CONTINUOUS (40-sec)" : "ON-DEMAND (Geolocator)"}');

      if (isContinuous) {
        // ⚡ INSTANT: Get location from 40-second tracking table
        try {
          final db = DatabaseHelper();
          final latestLocData = await db.getLatestLocation();

          if (latestLocData != null) {
            lat = (latestLocData['latitude'] ?? 0.0).toString();
            long = (latestLocData['longitude'] ?? 0.0).toString();
            print('[LOCATION] 📍 Continuous tracking: lat=$lat, lng=$long');
          } else {
            print(
                '[LOCATION] ⚠️ No continuous tracking data, using default (0, 0)');
          }
        } catch (e) {
          print('[LOCATION] ⚠️ Error fetching continuous location: $e');
        }
      } else {
        // 📍 ON-DEMAND: Get fresh location via Geolocator
        final locationData =
            await _getFreshLocationForOrder(profile, party, activityType);
        lat = locationData['lat'] ?? "0";
        long = locationData['long'] ?? "0";
      }
    } catch (e) {
      print('[LOCATION] ⚠️ Unexpected error in _getLocationForOrder: $e');
    }

    return {'lat': lat, 'long': long};
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    var moduleEntryAccess = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "205",
          orElse: () => Modules(),
        ) ??
        Modules();
    if (moduleEntryAccess.mODULENO == "205") {
      viewRight = moduleEntryAccess.rEADRIGHT!;
      addRight = moduleEntryAccess.wRITERIGHT!;
      updateRight = moduleEntryAccess.uPDATERIGHT!;
      deleteRight = moduleEntryAccess.dELETERIGHT!;
      printRight = moduleEntryAccess.pRINTRIGHT!;
    } else {}

    super.initState();

    cart = Provider.of<CartListProvider>(context, listen: false);

    // if (controller.selectedPartyId.value.isNotEmpty)
    //   cart.getCartItem(Get.context, controller.selectedPartyId.value);

    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final party = Provider.of<PartyProvider>(context, listen: false);

      // Ensure latest settings are merged into ProfileProvider before deciding
      // stockist visibility/requirement.
      await profile.loadSettings(context);
      if (!mounted) return;

      final isStockistEnabled = _isStockistUserLinkEnabled(profile);

      // Restore persisted stockist only when user setting allows stockist link.
      if (isStockistEnabled) {
        await controller.restoreStockistSelection();
      } else {
        await controller.clearStockistSelection();
        controller.stockists.clear();
        controller.hasStockistAccess.value = false;
      }

      if ((widget.initialStockistCd ?? '').trim().isNotEmpty) {
        await _applyInitialStockistSelection(widget.initialStockistCd!.trim());
      }

      if (controller.selectedPartyId.value.isNotEmpty) {
        cartController.productAddedStates.clear(); // Clear previous state

        // ⚡ INSTANT: Load from local cache SYNCHRONOUSLY before rendering
        try {
          final localCartItems = await DatabaseHelper()
              .getCartItems(partyId: controller.selectedPartyId.value);
          print('[PRODUCT_PAGE-PHASE1] 📊 LOCAL DB LOAD:');
          print(
              '[PRODUCT_PAGE-PHASE1]   Total items: ${localCartItems.length}');
          for (var item in localCartItems) {
            String itemCd = item['item_cd']?.toString() ?? '';
            int qty = (item['quantity'] as num?)?.toInt() ?? 0;
            if (itemCd.isNotEmpty) {
              print('[PRODUCT_PAGE-PHASE1]   - ItemCd: $itemCd, Qty: $qty');
              cartController.productAddedStates[itemCd] = true;
            }
          }
          cartController.cartCount.value =
              cartController.productAddedStates.length;
          cartController.update();
          print(
              '[PRODUCT_PAGE-PHASE1] ✅ Loaded ${localCartItems.length} items from local cache immediately');
        } catch (e) {
          print('[PRODUCT_PAGE-PHASE1] ⚠️ Error loading local cache: $e');
        }

        // 📡 BACKGROUND: Fetch from server and update (non-blocking)
        Future.microtask(() async {
          try {
            print('[PRODUCT_PAGE-PHASE2] 🌐 SERVER SYNC START...');
            await cart.getCartItem(
                Get.context!, controller.selectedPartyId.value);

            print('[PRODUCT_PAGE-PHASE2] 📊 SERVER RESPONSE:');
            print('[PRODUCT_PAGE-PHASE2]   Total items: ${cart.data.length}');
            for (var item in cart.data) {
              int qty = (item.quantity as num?)?.toInt() ?? 0;
              print(
                  '[PRODUCT_PAGE-PHASE2]   - ItemCd: ${item.itemCd}, Qty: $qty, Amount: ${item.amount}');
              cartController.productAddedStates[item.itemCd] = true;
            }

            cartController.cartCount.value =
                cartController.productAddedStates.length;
            cartController.update();
            print('[PRODUCT_PAGE-PHASE2] ✅ Synced cart with server');
          } catch (e) {
            print('[PRODUCT_PAGE-PHASE2] ⚠️ Failed to sync cart: $e');
          }
        });
      }

      // Refresh stockists only when stockist link is enabled for this user.
      if (isStockistEnabled) {
        await controller.fetchStockists(groupCd: '136');

        if ((widget.initialStockistCd ?? '').trim().isNotEmpty) {
          await _applyInitialStockistSelection(
              widget.initialStockistCd!.trim());
        }
      }

      // Fetch monthly target data for stockists
      await _fetchMonthlyTargetData();

      // Initialize filteredDepartments by copying contents from deptment
      controller.filteredDepartments.assignAll(controller.deptment);
    });
  }

  Timer? timer;

  bool _isStockistUserLinkEnabled(ProfileProvider profile) {
    final settings = profile.data?.profileSettings;
    if (settings == null || settings.isEmpty) {
      return false;
    }

    final stockistSetting = settings.firstWhereOrNull(
      (e) => (e.variable?.toString().trim() ?? '') == 'showStockistUserLink',
    );

    if (stockistSetting == null) {
      return false;
    }

    final normalizedValue =
        stockistSetting.value?.toString().trim().toUpperCase() ?? '';
    return normalizedValue == 'Y';
  }

  bool _requiresStockistSelection(ProfileProvider profile) {
    if (!_isStockistUserLinkEnabled(profile)) {
      return false;
    }

    final hasStockistOptions =
        controller.hasStockistAccess.value || controller.stockists.isNotEmpty;

    return hasStockistOptions && controller.selectedStockistId.value.isEmpty;
  }

  Future<void> _applyInitialStockistSelection(String stockistCd) async {
    final code = stockistCd.trim();
    if (code.isEmpty) {
      return;
    }

    try {
      DatumPartyname? matchedStockist;
      for (final stockist in controller.stockists) {
        if (stockist.accCd.trim() == code) {
          matchedStockist = stockist;
          break;
        }
      }

      if (matchedStockist != null) {
        controller.selectedStockistName.value = matchedStockist.accName;
        controller.selectedStockistId.value = matchedStockist.accCd;
        controller.selectedStockistAddress.value = matchedStockist.accAddress;
        controller.selectedStockistCity.value = matchedStockist.city ?? '';
        controller.selectedStockistMobile.value = matchedStockist.mobile;
        controller.selectedStockistPersonName.value =
            matchedStockist.person_nm ?? '';
        controller.selectedStockistPincode.value =
            matchedStockist.pincode ?? '';
        controller.hasStockistAccess.value = true;
        await controller.saveStockistSelection();
      } else {
        controller.selectedStockistId.value = code;
        await controller.saveStockistSelection();
      }
    } catch (e) {
      print('[Product] Error applying initial stockist selection: $e');
    }
  }

  Future<void> _fetchMonthlyTargetData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;
      if (token == null || token.trim().isEmpty) {
        return;
      }

      final targetMonth = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final tempMap = <String, Map<String, dynamic>>{};
      Future<void> loadType(String type) async {
        final uri = Uri.parse(
          '${AppConfig.baseURL}monthly-sales-target?targetMonth=$targetMonth&type=$type',
        );

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
          },
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          return;
        }

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        if (data is! List || data.isEmpty) {
          return;
        }

        for (final item in data.whereType<Map>()) {
          final stockistCd = (item['STOCKIST_CD'] ?? '').toString().trim();
          if (stockistCd.isEmpty) {
            continue;
          }

          final entry =
              tempMap.putIfAbsent(stockistCd, () => <String, dynamic>{});
          if (type.toUpperCase() == 'PRIMARY') {
            entry['primaryTargetAmount'] = item['PRIMARY_TARGET_AMOUNT'] ?? 0;
            entry['primaryTargetDesc'] = (item['TARGET_DESC'] ?? '').toString();
            entry['updatedAt'] = item['UPDATED_AT'] != null
                ? DateFormat('yyyy-MM-dd')
                    .format(DateTime.parse(item['UPDATED_AT']))
                : '';
          } else if (type.toUpperCase() == 'POB') {
            entry['pobAmount'] = item['POB_AMOUNT'] ?? 0;
            entry['pobTargetDesc'] = (item['TARGET_DESC'] ?? '').toString();
            entry['pobLastSyncAt'] =
                (item['POB_LAST_SYNC_AT'] ?? '').toString();
          }
        }
      }

      await Future.wait([
        loadType('PRIMARY'),
        loadType('POB'),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _monthlyTargetByStockist = tempMap;
      });
    } catch (e) {
      print('[Product] Error fetching monthly target data: $e');
    }
  }

  String _amountToString(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0.0;
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return WillPopScope(
      onWillPop: () async {
        Get.back(result: true);
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true, // <-- this must be true
        appBar: MyAppBar(
          title: 'Products',
          partyID: controller.selectedPartyId.value,
          menuItem: [
            if (printRight)
              buildMenuItem(
                icon: Icons.picture_as_pdf,
                text: 'Export Item PDF',
                isLoading: controller.isDownloadingExportPdf.value,
                onTap: () async {
                  controller.isDownloadingExportPdf.value = true;

                  try {
                    final pdfUrl = await Services().getProductExportFile(
                      Get.context!,
                      controller.searchController.text.trim(),
                      controller.selectedChip.value,
                    );

                    if (pdfUrl != null) {
                      log("Product PDF Export Successful: $pdfUrl");

                      Get.to(() => PdfViewerScreen(
                            pdfUrl: pdfUrl,
                            fileName: DateTime.now().toString(),
                          ));
                    } else {
                      log("No Product PDF file returned.");
                    }
                  } catch (error) {
                    log("Error retrieving Product PDF file: $error");
                  } finally {
                    controller.isDownloadingExportPdf.value = false;
                  }
                },
              ),
            //if(printRight)
            buildMenuItem(
              icon: Icons.search,
              text: 'Department Search',
              onTap: () async {
                setState(() {
                  controller.searchController.clear();
                  // Toggle department search without clearing the loaded departments
                  controller.showDeptSearch.value =
                      !controller.showDeptSearch.value;
                  controller.showSearch.value = false;
                });
                Get.back();
              },
            ),
            if (printRight)
              buildMenuItem(
                icon: Icons.file_download,
                text: 'Export Party PDF',
                isLoading: controller.isDownloadingPartyExportPdf.value,
                onTap: () async {
                  controller.isDownloadingPartyExportPdf.value = true;

                  try {
                    final pdfUrl =
                        await Services().getPartyExportFile(Get.context!);

                    if (pdfUrl != null) {
                      log("Party PDF Export Successful: $pdfUrl");

                      Get.to(() => PdfViewerScreen(
                            pdfUrl: pdfUrl,
                            fileName: DateTime.now().toString(),
                          ));
                    } else {
                      log("No Party PDF file returned.");
                    }
                  } catch (error) {
                    log("Error retrieving Party PDF file: $error");
                  } finally {
                    controller.isDownloadingPartyExportPdf.value = false;
                  }
                },
              ),
          ],
        ),
        body: SafeArea(
          child: profile.data != null &&
                  profile.data!.modulesList!
                      .any((module) => module.mODULENO == "205")
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // if (profile.data!.profileSettings.any((e) =>
                      //     e.variable == 'showStockistUserLink' &&
                      //     e.value == 'Y'))
                      _buildStockistHeader(),
                      _buildPartyHeader(profile),
                      _buildChipSelector(),
                      Expanded(child: _buildProductList()),
                    ],
                  ),
                )
              : _buildPermissionDeniedMessage(),
        ),
      ),
    );
  }

  /// **Party Header Widget**
  Widget _buildPartyHeader(ProfileProvider profile) {
    // Get the current PartyProvider instance from the context
    final party = context.watch<PartyProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Label for the party header
        const Padding(
          padding: EdgeInsets.only(left: 5.0),
          child: Text(
            'Party :',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        // Party name with reactive updates
        Obx(() {
          final partyName = controller.selectedPartyName.value;

          return Expanded(
            child: Text(
              Helper.trimValue(partyName, 35),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }),

        // Dynamic action button based on state
        if (profile.YN == "Y")
          profile.ACC_NAME.isEmpty && profile.ACC_CD.isEmpty
              ? TextButton(
                  onPressed: _isOrderProcessing
                      ? null
                      : () async {
                          // ⚡ Prevent multiple clicks
                          if (_isOrderProcessing) return;

                          // Validation 1: Check if punched in
                          if (profile.data?.isPunchIn != true) {
                            AppSnackBar.showGetXCustomSnackBar(
                                message: 'Please Punch In');
                            return;
                          }

                          // Validation 2: Check if stockist is required but not selected
                          if (_requiresStockistSelection(profile)) {
                            AppSnackBar.showGetXCustomSnackBar(
                                message: 'Please Select Stockist');
                            return;
                          }

                          // Check if module 120 is available with READ_RIGHT
                          final hasModule120 = profile.data != null &&
                              profile.data!.modulesList != null &&
                              profile.data!.modulesList!.any((module) =>
                                  module.mODULENO == "120" &&
                                  module.rEADRIGHT == true);

                          // If module 120 is not available, skip selfie and show menu
                          if (!hasModule120) {
                            showMenu();
                          } else {
                            // All validations passed - check selfie
                            final selfieOk = await _checkSelfieUploadedToday();
                            if (selfieOk) {
                              showMenu();
                            } else {
                              final profile = Provider.of<ProfileProvider>(
                                  context,
                                  listen: false);
                              final party = Provider.of<PartyProvider>(context,
                                  listen: false);
                              final uploaded = await _showSelfieDialogAndUpload(
                                  profile, party);
                              if (uploaded) showMenu();
                            }
                          }
                        },
                  child: _isOrderProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Processing..."),
                          ],
                        )
                      : const Text("Start Order"),
                )
              : TextButton(
                  onPressed: _isOrderProcessing
                      ? null
                      : () async {
                          // ⚡ Prevent multiple clicks
                          if (_isOrderProcessing) return;

                          setState(() {
                            _isOrderProcessing = true;
                          });

                          print('[END_ORDER] ⚡ Immediate: End order clicked');

                          try {
                            // ⚡⚡⚡ Call API immediately (uses cached location)
                            await party.startEndOrder(
                              profile.ACC_NAME,
                              profile.ACC_CD,
                              context,
                              "3",
                              id: 1,
                            );

                            print('[END_ORDER] ✅ Order ended successfully');

                            // Clear the selected party name
                            controller.selectedPartyName.value = '';
                            controller.selectedPartyId.value = '';

                            // Reset state
                            setState(() {
                              dataProduct.clear();
                              isLoading = true;
                              qty.clear();
                              freeQty.clear();
                            });

                            // Clear cart
                            cartController.productAddedStates.clear();

                            // 📦 Background: Fetch products (non-blocking)
                            print(
                                '[END_ORDER] 📦 Background: Fetching products...');
                            Future.microtask(() async {
                              if (!mounted)
                                return; // ✅ Guard: widget might be disposed
                              try {
                                await controller.fetchProductsFromAPI();
                                print(
                                    '[END_ORDER] ✅ Background: Products fetched');

                                setState(() {
                                  isLoading = false;
                                });

                                if (controller.selectedPartyId.isNotEmpty) {
                                  cartController.productAddedStates.clear();
                                  await cart.getCartItem(Get.context!,
                                      controller.selectedPartyId.value);

                                  for (var item in cart.data) {
                                    cartController
                                        .productAddedStates[item.itemCd] = true;
                                  }

                                  cartController.update();

                                  cartController.cartCount.value =
                                      cartController.productAddedStates.length;
                                  cartController
                                      .update(); // Ensure UI rebuilds with new count
                                } else {
                                  cartController.cartCount.value = 0;
                                  cartController.update(); // Ensure UI rebuilds
                                }
                              } catch (e) {
                                print('[END_ORDER] ❌ Background error: $e');
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            });
                          } catch (e) {
                            print('[END_ORDER] ❌ Error: $e');
                            AppSnackBar.showGetXCustomSnackBar(
                                message: "Error: $e");
                          } finally {
                            setState(() {
                              _isOrderProcessing = false;
                            });
                          }
                        },
                  child: _isOrderProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text("Processing..."),
                          ],
                        )
                      : const Text("End Order"),
                )
        else
          TextButton(
            onPressed: () {
              if (_requiresStockistSelection(profile)) {
                AppSnackBar.showGetXCustomSnackBar(
                    message: 'Please Select Stockist');
                return;
              }
              showMenu();
            },
            child: const Text("Change"),
          ),
      ],
    );
  }

  /// **Chip Selector Widget**
  // ignore: unused_element
  Widget _buildChipSelector1() {
    return Obx(() {
      if (controller.isDpLoading.value) return const LinearProgressIndicator();

      return SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.deptment.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final department = controller.deptment[index];

            return Obx(
              () => SelectableChip(
                label: department.deptName,
                isSelected: controller.selectedChip.value == department.deptCd,
                onSelected: (bool selected) {
                  controller
                      .toggleChipSelection(selected ? department.deptCd : '');
                  log("Selected Department Code: ${controller.selectedChip.value}");
                },
              ),
            );
          },
        ),
      );
    });
  }

  /// **Stockist Header Widget** - Shows stockist selection when groupCd=136 is available
  Widget _buildStockistHeader() {
    return Obx(() {
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final hasStockistAccess = controller.hasStockistAccess.value;
      final isStockistLoading = controller.isStockistLoading.value;
      final selectedStockistName = controller.selectedStockistName.value;

      if (!_isStockistUserLinkEnabled(profile)) {
        return const SizedBox.shrink();
      }

      final shouldHide = (!hasStockistAccess &&
          !isStockistLoading &&
          selectedStockistName.isEmpty);

      if (shouldHide) {
        return const SizedBox.shrink();
      }

      return Column(
        children: [
          Container(
            // padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 5.0),
                  child: Text(
                    'Stockist :',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedStockistName.isNotEmpty
                        ? selectedStockistName
                        : 'Select Stockist',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedStockistName.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                if (selectedStockistName.isNotEmpty)
                  // TextButton(
                  //   onPressed: () async {
                  //     await controller.clearStockistSelection();
                  //   },
                  //   child: const Text('Unselect', style: TextStyle(color: Colors.red)),
                  // ),
                  GestureDetector(
                    onTap: () async {
                      await controller.clearStockistSelection();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                    ),
                  ),
                SizedBox(
                  width: 10,
                ),
                TextButton(
                  onPressed: () {
                    showStockistMenu();
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Future<void> showStockistMenu() async {
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    if (!_isStockistUserLinkEnabled(profile)) {
      return;
    }

    // Ensure monthly target data is available before opening the sheet
    if (_monthlyTargetByStockist.isEmpty) {
      try {
        await _fetchMonthlyTargetData();
      } catch (e) {
        print(
            '[Product] Error fetching monthly target before showing sheet: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Obx(() {
          if (controller.isStockistLoading.value) {
            return SizedBox(
              height: 200,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (controller.stockists.isEmpty) {
            return SizedBox(
              height: 200,
              child: const Center(child: Text('No stockists available')),
            );
          }

          return SizedBox(
            height: 450,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20.0, top: 20.0, bottom: 10),
                  child: Text(
                    "Select Stockist:",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.stockists.length,
                    itemBuilder: (context, index) {
                      final stockist = controller.stockists[index];
                      final name = stockist.accName;
                      final code = stockist.accCd;

                      return InkWell(
                        onTap: () async {
                          controller.selectedStockistName.value = name;
                          controller.selectedStockistId.value = code;
                          controller.selectedStockistMobile.value =
                              stockist.mobile;
                          await controller.saveStockistSelection();
                          Navigator.pop(context);
                          print(
                              '[Product] Selected Stockist: $name ($code), Mobile: ${stockist.mobile}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$name ($code)",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (stockist.accAddress.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              stockist.accAddress,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (stockist.mobile.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.phone,
                                              size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            stockist.mobile,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    // if (stockist.lat != null &&
                                    //     stockist.long != null) ...[
                                    //   const SizedBox(height: 4),
                                    //   Row(
                                    //     children: [
                                    //       const Icon(Icons.location_on_outlined,
                                    //           size: 14, color: Colors.green),
                                    //       const SizedBox(width: 4),
                                    //       Text(
                                    //         '${stockist.lat}, ${stockist.long}',
                                    //         style: TextStyle(
                                    //           fontSize: 11,
                                    //           color: Colors.grey.shade700,
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ],
                                    if (_monthlyTargetByStockist
                                        .containsKey(code)) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_monthlyTargetByStockist[code]
                                                    ?.containsKey(
                                                        'primaryTargetAmount') ??
                                                false) ...[
                                              Row(
                                                children: [
                                                  const Icon(Icons.file_copy,
                                                      size: 14,
                                                      color: Colors.blue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Primary: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '₹ ${_amountToString(_monthlyTargetByStockist[code]?['primaryTargetAmount'])}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  Text(
                                                    'Updated At: ${_monthlyTargetByStockist[code]?['updatedAt']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // if (((_monthlyTargetByStockist[
                                              //                     code]?[
                                              //                 'primaryTargetDesc'] ??
                                              //             '')
                                              //         .toString()
                                              //         .trim())
                                              //     .isNotEmpty)
                                              //   Text(
                                              //     'Desc: ${_monthlyTargetByStockist[code]?['primaryTargetDesc']}',
                                              //     style: TextStyle(
                                              //       fontSize: 11,
                                              //       color: Colors.grey.shade700,
                                              //     ),
                                              //   ),
                                            ],
                                            if (_monthlyTargetByStockist[code]
                                                    ?.containsKey(
                                                        'pobAmount') ??
                                                false) ...[
                                              if (_monthlyTargetByStockist[code]
                                                      ?.containsKey(
                                                          'primaryTargetAmount') ??
                                                  false)
                                                const SizedBox(height: 6),
                                              // Text(
                                              //   'POB',
                                              //   style: TextStyle(
                                              //     fontSize: 12,
                                              //     fontWeight: FontWeight.w600,
                                              //     color: Colors.blue.shade900,
                                              //   ),
                                              // ),
                                              // const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'POB: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    '₹ ${_amountToString(_monthlyTargetByStockist[code]?['pobAmount'])}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // if (((_monthlyTargetByStockist[
                                              //                     code]?[
                                              //                 'pobTargetDesc'] ??
                                              //             '')
                                              //         .toString()
                                              //         .trim())
                                              //     .isNotEmpty)
                                              //   Text(
                                              //     'Desc: ${_monthlyTargetByStockist[code]?['pobTargetDesc']}',
                                              //     style: TextStyle(
                                              //       fontSize: 11,
                                              //       color: Colors.grey.shade700,
                                              //     ),
                                              //   ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_outline,
                                color:
                                    controller.selectedStockistId.value == code
                                        ? Colors.blue
                                        : Colors.grey.shade300,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// Show dialog to select stockist

  Widget _buildChipSelector() {
    return Obx(() {
      if (controller.isDpLoading.value) return const LinearProgressIndicator();

      return SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: controller.filteredDepartments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final department = controller.filteredDepartments[index];

            return Obx(
              () => SelectableChip(
                label: department.deptName,
                isSelected: controller.selectedChip.value == department.deptCd,
                onSelected: (bool selected) {
                  controller
                      .toggleChipSelection(selected ? department.deptCd : '');
                  //controller.showDeptSearch.value = false; // Hide search after selection
                  log("Selected Department Code: ${controller.selectedChip.value}");
                },
              ),
            );
          },
        ),
      );
    });
  }

  /// **Product List Widget**
  ///
  Widget _buildProductList() {
    // ScrollController _scrollController = ScrollController();
    //
    // // Listen for scroll events to hide the keyboard
    // _scrollController.addListener(() {
    //   // Hide keyboard on any scroll direction (up or down)
    //   //if(controller.isKeyboardOpen.value){
    //   FocusScope.of(context).unfocus();
    //   //controller.isKeyboardOpen.value =  false;
    //   //}
    // });

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.filteredProducts.isEmpty) {
        return const Center(
          child: Text("No products available.",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        );
      }

      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        //controller: _scrollController, // Attach the scroll controller here
        itemCount: controller.filteredProducts.length,
        shrinkWrap: true,
        //clipBehavior: Clip.none,
        itemBuilder: (context, index) {
          // var isadd = cart.data.any(
          //         (element) =>
          //     element.itemCd ==
          //         controller.filteredProducts[index].itemCd);

          return ProductCard(
            product: controller.filteredProducts[index],
          );
        },
      );
    });
  }

  /// **Permission Denied Message**
  Widget _buildPermissionDeniedMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "You do not have permission to access the Order Entry. Please upgrade your subscription.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  TextEditingController searchPartyClt = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List _tempParty = [];

  void showMenu1() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);

    // ⚡ IMPORTANT: Show menu INSTANTLY without waiting for sort!
    print('[PARTY_MENU] ⚡ START_ORDER: Showing cached party list instantly...');

    // Only mark sorting as in progress if it will actually happen
    final bool willSort = _isContinuousLocationTrackingEnabled(profile);
    _isSorting = willSort;

    // Show the menu immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Consumer<PartyProvider>(
          builder: (context, party, child) {
            return StatefulBuilder(builder: (context, setState) {
              return Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: SizedBox(
                  height: 450,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSorting)
                        Container(
                          height: 40,
                          color: Colors.grey[100],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Sorting by location...',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      _buildSearchField(setState, party),
                      _buildPartyList(
                        setState,
                        Provider.of<ProfileProvider>(context, listen: false),
                        party,
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        );
      },
    );

    // 📍 Sort parties by distance in background (non-blocking) - only if enabled
    if (willSort) {
      Future.microtask(() async {
        try {
          await pp.sortPartiesByDistance();
          print('[PARTY_MENU] ✅ Background: Party list sorted by distance');
        } catch (e) {
          print('[PARTY_MENU] ⚠️ Background: Sort failed: $e');
        } finally {
          if (mounted) {
            this.setState(() {
              _isSorting = false;
            });
          }
        }
      });
    } else {
      print(
          '[PARTY_MENU] ⏭️ Skipped party distance sort because continuousLocationTracking != Y');
    }
  }

  Future<void> showMenu() async {
    // 🛡️ Mounted guard: Prevent null context crash if user navigates away
    if (!mounted) return;

    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    if (_requiresStockistSelection(p)) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Please Select Stockist');
      return;
    }

    // ⚡ IMPORTANT: Show menu INSTANTLY without waiting for sort!
    print(
        '[PARTY_MENU] ⚡ Using cached party list (no API call, showing instantly)...');
    _tempParty = [];
    searchPartyClt.clear();
    final BuildContext pageContext = context;

    Future.microtask(() async {
      try {
        await pp.getPartyNameProductPage(pageContext);
        final profile =
            Provider.of<ProfileProvider>(pageContext, listen: false);
        final bool willSort = _isContinuousLocationTrackingEnabled(profile);

        if (willSort) {
          // Only show sorting loader if it will actually happen
          if (mounted) {
            this.setState(() {
              _isSorting = true;
            });
          }
          await pp.sortPartiesByDistance();
          print('[PARTY_MENU] ✅ Background: Party list sorted by distance');
        } else {
          print(
              '[PARTY_MENU] ⏭️ Skipped menu party sort because continuousLocationTracking != Y');
        }
      } catch (e) {
        print('[PARTY_MENU] ⚠️ Party load failed: $e');
      } finally {
        if (mounted) {
          this.setState(() {
            _isSorting = false;
          });
        }
      }
    });

    // Show bottom sheet immediately
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        builder: (BuildContext context) {
          return Consumer<PartyProvider>(
            builder: (context, party, child) {
              return StatefulBuilder(builder: (context, StateSetter setStatee) {
                return Padding(
                  padding: MediaQuery.of(context).viewInsets,
                  child: SizedBox(
                    height: 450,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isSorting)
                          Container(
                            height: 40,
                            color: Colors.grey[100],
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 10),
                                Text('Sorting by location...',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20.0, bottom: 5.0, top: 20.0),
                                  child: Text("Select Party:",
                                      style: TextStyle(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8)),
                                ),
                                // Add Account button (Module 102)
                                if (p.data?.modulesList != null &&
                                    p.data!.modulesList!.any((module) =>
                                        module.mODULENO == "102" &&
                                        (module.wRITERIGHT == true ||
                                            module.uPDATERIGHT == true)))
                                  TextButton(
                                    onPressed: () async {
                                      final accName = await Get.to(
                                        () => const AddAccountScreen(),
                                        binding: AccountBindings(),
                                      );

                                      if (accName != null &&
                                          accName is String) {
                                        //  STEP 1: Refresh party list (VERY IMPORTANT)
                                        await pp.getPartyNameProductPage(
                                            pageContext);

                                        //  STEP 2: Rebuild bottom sheet UI
                                        if (mounted && context.mounted) {
                                          setStatee(() {});
                                        }

                                        //  STEP 3: (Optional) Update selected values
                                        controller.selectedPartyName.value =
                                            accName;
                                        controller.selectedPartyId.value = '';
                                      }
                                    },
                                    child: const Text('Add Account'),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CupertinoSearchTextField(
                                  controller: searchPartyClt,
                                  onChanged: (value) {
                                    //4
                                    if (mounted && context.mounted) {
                                      setStatee(() {
                                        final searchResults =
                                            Helper.buildSearchList(
                                                value, party);
                                        // Filter out stockists from search results
                                        _tempParty = searchResults
                                            .where((p) => p.groupCD != 136)
                                            .toList();
                                      });
                                    }
                                  }),
                            ),
                          ],
                        ),
                        Expanded(
                          child: party.loading ||
                                  (party.data.isEmpty && !party.nolistParty)
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : party.nolistParty == true
                                  ? const Center(
                                      child: Text("No List"),
                                    )
                                  : ListView.builder(
                                      itemCount: (_tempParty.isNotEmpty)
                                          ? _tempParty.length
                                          : party.data.length,
                                      itemBuilder: (builder, index) {
                                        return InkWell(
                                          onTap: _isOrderProcessing
                                              ? null
                                              : () async {
                                                  // ⚡ Prevent multiple clicks
                                                  if (_isOrderProcessing)
                                                    return;

                                                  this.setState(() {
                                                    _isOrderProcessing = true;
                                                  });

                                                  print(
                                                      '[START_ORDER] ⚡ Immediate: Party selected from list');

                                                  // Close the bottom sheet
                                                  Navigator.pop(context);

                                                  try {
                                                    final selectedParty =
                                                        (_tempParty.isNotEmpty)
                                                            ? _tempParty[index]
                                                            : party.data[index];

                                                    controller.selectedPartyName
                                                            .value =
                                                        selectedParty.accName;
                                                    controller.selectedPartyId
                                                            .value =
                                                        selectedParty.accCd;

                                                    print(
                                                        '[START_ORDER] 📝 Party selected: ${selectedParty.accName} (${selectedParty.accCd})');

                                                    // ⚡⚡⚡ API call immediately (no dialog!)
                                                    final isPunchInOutEnabled = p
                                                            .data
                                                            ?.profileSettings
                                                            .any((e) =>
                                                                e.variable ==
                                                                    'punchInOut' &&
                                                                e.value ==
                                                                    'Y') ??
                                                        false;

                                                    if (isPunchInOutEnabled) {
                                                      final LocationProvider
                                                          lp = Provider.of<
                                                                  LocationProvider>(
                                                              pageContext,
                                                              listen: false);
                                                      if (lp.enebleLocationPermission ==
                                                          true) {
                                                        print(
                                                            '[START_ORDER] 🚀 Starting punch-in order (immediate)');
                                                        await party
                                                            .changePunchInOutParty(
                                                                selectedParty
                                                                    .accName,
                                                                selectedParty
                                                                    .accCd,
                                                                isProductPage:
                                                                    true,
                                                                type: "1",
                                                                pageContext);
                                                      } else {
                                                        AppSnackBar
                                                            .showGetXCustomSnackBar(
                                                                message:
                                                                    "Please Enable Location Permission");
                                                        return;
                                                      }
                                                    } else {
                                                      print(
                                                          '[START_ORDER] 🚀 Starting regular order (immediate)');
                                                      await party.changeParty(
                                                          selectedParty.accName,
                                                          selectedParty.accCd,
                                                          pageContext);
                                                    }

                                                    print(
                                                        '[START_ORDER] ✅ Start order API completed');

                                                    // Update UI immediately
                                                    this.setState(() {
                                                      dataProduct.clear();
                                                      isLoading = true;
                                                      qty.clear();
                                                      freeQty.clear();
                                                    });

                                                    print(
                                                        '[START_ORDER] 📦 Background: Fetching products...');
                                                    // 📦 Background: Fetch products and cart (non-blocking)
                                                    Future.microtask(() async {
                                                      if (!mounted)
                                                        return; // ✅ Guard: widget might be disposed
                                                      try {
                                                        await controller
                                                            .fetchProductsFromAPI();
                                                        print(
                                                            '[START_ORDER] ✅ Background: Products fetched');

                                                        if (controller
                                                            .selectedPartyId
                                                            .isNotEmpty) {
                                                          cartController
                                                              .productAddedStates
                                                              .clear();

                                                          await cart.getCartItem(
                                                              pageContext,
                                                              controller
                                                                  .selectedPartyId
                                                                  .value);

                                                          for (var item
                                                              in cart.data) {
                                                            cartController
                                                                    .productAddedStates[
                                                                item.itemCd] = true;
                                                          }

                                                          cartController
                                                              .update();

                                                          cartController
                                                                  .cartCount
                                                                  .value =
                                                              cartController
                                                                  .productAddedStates
                                                                  .length;
                                                          print(
                                                              '[START_ORDER] ✅ Background: Cart updated');
                                                        }

                                                        this.setState(() {
                                                          isLoading = false;
                                                        });
                                                      } catch (e) {
                                                        print(
                                                            '[START_ORDER] ❌ Background error: $e');
                                                        this.setState(() {
                                                          isLoading = false;
                                                        });
                                                      }
                                                    });
                                                  } catch (e) {
                                                    print(
                                                        '[START_ORDER] ❌ Error: $e');
                                                    AppSnackBar
                                                        .showGetXCustomSnackBar(
                                                            message:
                                                                "Error: $e");
                                                  } finally {
                                                    this.setState(() {
                                                      _isOrderProcessing =
                                                          false;
                                                    });
                                                  }
                                                },
                                          child: (_tempParty.isNotEmpty)
                                              ? Helper
                                                  .showPartyBottomSheetWithSearch(
                                                      index, _tempParty,
                                                      showEditButton:
                                                          _canEditParty)
                                              : Helper
                                                  .showPartyBottomSheetWithSearch(
                                                      index, party.data,
                                                      showEditButton:
                                                          _canEditParty),
                                        );
                                      }),
                        )
                      ],
                    ),
                  ),
                );
              });
            },
          );
        });
  }

// Build Search Field
  Widget _buildSearchField(StateSetter setState, PartyProvider party) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, bottom: 5.0, top: 20.0),
          child: const Text(
            "Select Party:",
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CupertinoSearchTextField(
            controller: searchPartyClt,
            focusNode: _focusNode,
            onChanged: (value) {
              setState(() {
                final searchResults = Helper.buildSearchList(value, party);
                // Filter out stockists from search results too
                _tempParty =
                    searchResults.where((p) => p.groupCD != 136).toList();
              });
            },
          ),
        ),
      ],
    );
  }

// Build Party List
  Widget _buildPartyList(
      StateSetter setState, ProfileProvider profile, PartyProvider party) {
    // Filter out stockists (groupCD 136) - only show parties (groupCD 85 or 135)
    final partiesOnly = party.data.where((p) => p.groupCD != 136).toList();

    return Expanded(
      child: party.nolistParty
          ? const Center(child: Text("No List"))
          : party.data.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _tempParty.isNotEmpty
                      ? _tempParty.length
                      : partiesOnly.length,
                  itemBuilder: (context, index) {
                    return _buildPartyListItem(setState, profile, party, index);
                  },
                ),
    );
  }

// Build Individual Party List Item
  Widget _buildPartyListItem(StateSetter setState,
      ProfileProvider profileProvider, PartyProvider partyProvider, int index) {
    // Filter out stockists - only show parties
    final partiesOnly =
        partyProvider.data.where((p) => p.groupCD != 136).toList();

    return GestureDetector(
      onTap: () async {
        try {
          final selectedParty = _tempParty.isNotEmpty
              ? _tempParty[index]
              : partiesOnly[index]; // Use filtered list

          controller.selectedPartyName.value = selectedParty.accName;
          controller.selectedPartyId.value = selectedParty.accCd;

          log("Selected Party Name: ${controller.selectedPartyName.value}");
          log("Selected Party ID: ${controller.selectedPartyId.value}");

          // Close the bottom sheet
          Navigator.pop(context);

          print('[START_ORDER] ⚡ Immediate: Party selected - $selectedParty');

          // ⚡⚡⚡ Start order processing immediately (uses cached location)
          try {
            final isPunchInOutEnabled = profileProvider.data?.profileSettings
                    .any((setting) =>
                        setting.variable == 'punchInOut' &&
                        setting.value == 'Y') ??
                false;

            if (isPunchInOutEnabled) {
              final locationProvider =
                  Provider.of<LocationProvider>(context, listen: false);

              if (locationProvider.enebleLocationPermission) {
                print('[START_ORDER] 🚀 Starting punch-in order (immediate)');
                await partyProvider.changePunchInOutParty(
                  selectedParty.accName,
                  selectedParty.accCd,
                  isProductPage: true,
                  type: "1",
                  context,
                );
              } else {
                AppSnackBar.showGetXCustomSnackBar(
                    message: "Please Enable Location Permission");
                return;
              }
            } else {
              print('[START_ORDER] 🚀 Starting regular order (immediate)');
              await partyProvider.changeParty(
                selectedParty.accName,
                selectedParty.accCd,
                context,
              );
            }

            print('[START_ORDER] ✅ Start order API completed');

            // Update UI immediately
            if (mounted) {
              this.setState(() {
                dataProduct.clear();
                isLoading = true;
                qty.clear();
                freeQty.clear();
              });
            }

            print('[START_ORDER] 📦 Background: Fetching products...');
            // 📦 Background: Fetch products and cart (non-blocking)
            Future.microtask(() async {
              try {
                if (!mounted) return;
                await controller.fetchProductsFromAPI();
                print('[START_ORDER] ✅ Background: Products fetched');

                // Update cart
                if (controller.selectedPartyId.isNotEmpty) {
                  cartController.productAddedStates.clear();
                  if (!mounted) return;
                  await cart.getCartItem(
                      context, controller.selectedPartyId.value);

                  for (var item in cart.data) {
                    cartController.productAddedStates[item.itemCd] = true;
                  }

                  cartController.update();
                  cartController.cartCount.value =
                      cartController.productAddedStates.length;
                  cartController.update(); // Ensure UI rebuilds with new count
                  print('[START_ORDER] ✅ Background: Cart updated');
                }

                if (mounted) {
                  this.setState(() {
                    isLoading = false;
                  });
                }
              } catch (e) {
                print('[START_ORDER] ❌ Background error: $e');
                if (mounted) {
                  this.setState(() {
                    isLoading = false;
                  });
                }
              }
            });
          } catch (e) {
            print('[START_ORDER] ❌ Error: $e');
            AppSnackBar.showGetXCustomSnackBar(message: "Error: $e");
          }
        } catch (e) {
          log("Error selecting party: $e");
          AppSnackBar.showGetXCustomSnackBar(message: "Error: $e");
        }
      },
      child: Helper.showPartyBottomSheetWithSearch(
        index,
        _tempParty.isNotEmpty ? _tempParty : partiesOnly,
        showEditButton: _canEditParty,
      ),
    );
  }
}

// GET {{base_url}}/products/party?groupCd=136
