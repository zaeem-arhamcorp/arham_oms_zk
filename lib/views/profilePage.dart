import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:arham_corporation/views/monthly_target/screens/edit_monthly_target_view.dart';
import 'package:arham_corporation/views/monthly_target/screens/monthly_target_view.dart';
import 'package:arham_corporation/views/monthly_target/services/api_services.dart';
import 'package:arham_corporation/widgets/common_app_drawer.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'monthly_target/models/monthly_target_item_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const int _maxImageSize = 2 * 1024 * 1024;
  // It's good practice to initialize controllers in initState or late final
  // and dispose them in dispose().
  late TextEditingController _nameClt;
  late TextEditingController _codeClt; // Renamed for clarity
  late TextEditingController _addressClt;
  late TextEditingController _phoneNoClt; // Renamed for clarity
  late TextEditingController _emailController;
  late TextEditingController _monthlyTargetController;
  late MonthlyTargetApiService _monthlyTargetApiService;

  final ImagePicker _userImagePicker = ImagePicker();
  XFile? _selectedUserImage;
  String? _existingImageUrl;

  // Removed: get ub => null; // This was unused and likely a placeholder

  bool receiptDeleteRight = false;
  bool receiptReadRight = false;
  bool receiptPrintRight = false;
  bool paymentDeleteRight = false;
  bool paymentReadRight = false;
  bool orderDeleteRight = false;
  bool orderPrintRight = false;

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;

  @override
  void initState() {
    super.initState();
    _nameClt = TextEditingController();
    _codeClt = TextEditingController();
    _addressClt = TextEditingController();
    _phoneNoClt = TextEditingController();
    _emailController = TextEditingController();
    _monthlyTargetController = TextEditingController();
    _monthlyTargetApiService = Get.isRegistered<MonthlyTargetApiService>()
        ? Get.find<MonthlyTargetApiService>()
        : Get.put(MonthlyTargetApiService());
    _setData(); // Renamed for convention (private method)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImageFromChildrenApi();
      _loadMonthlyTargetAmount();
    });

    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    // var receiptEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "214");
    // receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
    //
    // print("Receipt Delete :" + receiptDeleteRight.toString());

    // var paymentEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "215");
    // paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
    //
    // print("Payment Delete :" + paymentDeleteRight.toString());

    var narrationEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "109",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (narrationEntryModule.mODULENO == "109") {
      narrationModuleNo = narrationEntryModule.mODULENO!;
      narrationReadRight = narrationEntryModule.rEADRIGHT!;
      narrationWriteRights = narrationEntryModule.wRITERIGHT!;
      narrationUpdateRights = narrationEntryModule.uPDATERIGHT!;
      narrationDeleteRight = narrationEntryModule.dELETERIGHT!;
      narrationPrintRights = narrationEntryModule.pRINTRIGHT!;
    } else {
      print("Module with mODULENO '109' not found.");
    }

    var receiptEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "214",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (receiptEntryModule.mODULENO == "214") {
      receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
      receiptReadRight = receiptEntryModule.rEADRIGHT!;
      receiptPrintRight = receiptEntryModule.pRINTRIGHT!;
      print("Receipt Delete: " + receiptDeleteRight.toString());
      print("Receipt Red: " + receiptReadRight.toString());
      print("Receipt Print: " + receiptPrintRight.toString());
    } else {
      print("Module with mODULENO '214' not found.");
    }

    var orderReportModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "304",
            orElse: () => Modules()) ??
        Modules();
    if (orderReportModule.mODULENO == "304") {
      orderPrintRight = orderReportModule.pRINTRIGHT!;
      print("Order Print :" + orderPrintRight.toString());
    } else {
      print("Module with mODULENO '304' not found.");
    }

    var paymentEntryModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "215",
            orElse: () =>
                Modules() // Provide a default instance of the `Module` class
            ) ??
        Modules();

    if (paymentEntryModule.mODULENO == "215") {
      paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
      paymentReadRight = paymentEntryModule.rEADRIGHT!;
      print("Payment Delete: " + paymentDeleteRight.toString());
    } else {
      print("Module with mODULENO '215' not found.");
    }
  }

  Future<void> _loadProfileImageFromChildrenApi() async {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    final ProfileProvider profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    final token = (userProvider.token ?? '').trim();
    if (token.isEmpty) {
      print('[PROFILE] users/children skipped: token is empty');
      return;
    }

    try {
      // Paginate through children API until no more data.
      final List<dynamic> users = <dynamic>[];
      int page = 1;
      const int maxPages = 50; // safety cap to avoid runaway loops

      while (page <= maxPages) {
        final uri = Uri.parse(AppConfig.childrenURL)
            .replace(queryParameters: {'page': page.toString()});
        print('[PROFILE] users/children GET $uri');
        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'x-app-type': 'oms',
          },
        );

        if (response.statusCode != 200) {
          print(
              '[PROFILE] users/children failed with status ${response.statusCode}');
          break;
        }

        final Map<String, dynamic> decoded =
            Map<String, dynamic>.from(json.decode(response.body));
        final List<dynamic> pageData = decoded['data'] is List
            ? List<dynamic>.from(decoded['data'])
            : <dynamic>[];

        users.addAll(pageData);

        // If meta indicates last_page, stop when reached.
        final meta = decoded['meta'];
        if (meta is Map) {
          final lastPage = meta['last_page'] is int
              ? meta['last_page'] as int
              : int.tryParse(meta['lastPage']?.toString() ?? '') ?? -1;
          if (lastPage > 0 && page >= lastPage) {
            break;
          }
          final perPage = meta['per_page'] is int
              ? meta['per_page'] as int
              : int.tryParse(meta['perPage']?.toString() ?? '') ?? null;
          if (perPage != null && pageData.length < perPage) {
            break; // last page reached
          }
        }

        if (pageData.isEmpty) {
          break; // no more data
        }

        page++;
      }

      // For backward compatibility keep meta variable usage below
      final Map<String, dynamic> meta = <String, dynamic>{};
      final currentUserCd =
          (meta['currentUserCd'] ?? profileProvider.data?.userCd ?? '')
              .toString()
              .trim();

      Map<String, dynamic>? selectedUser;

      for (final item in users) {
        if (item is! Map) continue;
        final user = Map<String, dynamic>.from(item);
        final isSelf = user['isSelf'] == true;
        final userCd = (user['USER_CD'] ?? '').toString().trim();

        if (isSelf || (currentUserCd.isNotEmpty && userCd == currentUserCd)) {
          selectedUser = user;
          break;
        }
      }

      if (selectedUser == null &&
          profileProvider.data?.userCd != null &&
          users.isNotEmpty) {
        final profileUserCd = profileProvider.data!.userCd.toString().trim();
        for (final item in users) {
          if (item is! Map) continue;
          final user = Map<String, dynamic>.from(item);
          if ((user['USER_CD'] ?? '').toString().trim() == profileUserCd) {
            selectedUser = user;
            break;
          }
        }
      }

      final dynamic rawImageUrl = selectedUser?['USER_IMAGE_URL'];
      var resolvedImageUrl = rawImageUrl == null ? '' : rawImageUrl.toString();
      resolvedImageUrl = resolvedImageUrl.trim();
      if (resolvedImageUrl.toLowerCase() == 'null') {
        resolvedImageUrl = '';
      }

      final dynamic rawEmail =
          selectedUser?['EMAIL_ID'] ?? selectedUser?['emailID'];
      var resolvedEmail = rawEmail == null ? '' : rawEmail.toString();
      resolvedEmail = resolvedEmail.trim();
      if (resolvedEmail.toLowerCase() == 'null') {
        resolvedEmail = '';
      }

      print(
          '[PROFILE] users/children resolved USER_IMAGE_URL: $resolvedImageUrl');
      print('[PROFILE] users/children resolved EMAIL_ID: $resolvedEmail');

      if (!mounted) {
        return;
      }

      setState(() {
        if (resolvedImageUrl.isNotEmpty) {
          _existingImageUrl = resolvedImageUrl;
        }
        _emailController.text =
            resolvedEmail.isNotEmpty ? resolvedEmail : 'No Email';
      });
    } catch (e) {
      print('[PROFILE] users/children error: $e');
    }
  }

  // It's good practice to dispose controllers
  @override
  void dispose() {
    _nameClt.dispose();
    _codeClt.dispose();
    _addressClt.dispose();
    _phoneNoClt.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickUserImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Capture from Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _userImagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    await _handleUserImage(image.path);
                  }
                },
              ),
              // ListTile(
              //   leading: const Icon(Icons.folder_open),
              //   title: const Text('Select from Files'),
              //   onTap: () async {
              //     Navigator.pop(context);
              //     final result = await FilePicker.platform.pickFiles(
              //       type: FileType.image,
              //       allowMultiple: false,
              //     );
              //     if (result != null && result.files.isNotEmpty) {
              //       final path = result.files.first.path;
              //       if (path != null && path.isNotEmpty) {
              //         await _handleUserImage(path);
              //       }
              //     }
              //   },
              // ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Select from Gallery'),
                onTap: () async {
                  Navigator.pop(context);

                  final image = await _userImagePicker.pickImage(
                    source: ImageSource.gallery,
                  );

                  if (image != null) {
                    await _handleUserImage(image.path);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onProfilePhotoTap(String existingImageUrl) async {
    final hasPhoto =
        _selectedUserImage != null || existingImageUrl.trim().isNotEmpty;

    if (!hasPhoto) {
      await _pickUserImage();
      return;
    }

    final shouldEdit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ProfilePhotoPreviewScreen(
          localImagePath: _selectedUserImage?.path,
          networkImageUrl: existingImageUrl,
        ),
      ),
    );

    if (shouldEdit == true && mounted) {
      await _pickUserImage();
    }
  }

  Future<String?> _openCropRotateEditor(String imagePath) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _ProfilePhotoEditorScreen(imagePath: imagePath),
      ),
    );
  }

  Future<void> _handleUserImage(String imagePath) async {
    final allowed = ['jpg', 'jpeg', 'png', 'webp'];
    final ext = imagePath.split('.').last.toLowerCase();
    if (!allowed.contains(ext)) {
      AppSnackBar.showGetXCustomSnackBar(
          message: "Only JPG, PNG, JPEG, WEBP allowed");
      return;
    }

    final editedImagePath = await _openCropRotateEditor(imagePath);
    if (editedImagePath == null || editedImagePath.isEmpty) {
      return;
    }

    String imagePathForUpload = editedImagePath;
    final file = File(imagePathForUpload);
    final size = await file.length();

    final editedExt = imagePathForUpload.split('.').last.toLowerCase();
    if (!allowed.contains(editedExt)) {
      AppSnackBar.showGetXCustomSnackBar(
          message: "Only JPG, PNG, JPEG, WEBP allowed");
      return;
    }

    if (size > _maxImageSize) {
      final compressedPath =
          await _compressImageToUnder2Mb(imagePathForUpload, editedExt);
      if (compressedPath == null || compressedPath.isEmpty) {
        AppSnackBar.showGetXCustomSnackBar(
            message: "Unable to compress image below 2MB");
        return;
      }
      imagePathForUpload = compressedPath;
    }

    final uploadFile = File(imagePathForUpload);
    final uploadSize = await uploadFile.length();
    if (uploadSize > _maxImageSize) {
      AppSnackBar.showGetXCustomSnackBar(
          message: "Unable to compress image below 2MB");
      return;
    }

    setState(() {
      _selectedUserImage = XFile(imagePathForUpload);
    });

    final uploaded = await _uploadUserImageToServer(imagePathForUpload);
    if (!uploaded) {
      return;
    }

    await _loadProfileImageFromChildrenApi();
  }

  Future<String?> _compressImageToUnder2Mb(
      String sourcePath, String ext) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[PROFILE] Compression skipped: source file missing');
        return null;
      }

      final normalizedExt = ext == 'jpeg' ? 'jpg' : ext;
      final outputExt = (normalizedExt == 'png' || normalizedExt == 'webp')
          ? normalizedExt
          : 'jpg';
      final compressFormat = _getCompressFormat(outputExt);

      var quality = 90;
      var minWidth = 1920;
      var minHeight = 1920;
      XFile? compressed;

      while (quality >= 20) {
        final targetPath = p.join(
          Directory.systemTemp.path,
          'profile_${DateTime.now().millisecondsSinceEpoch}_$quality.$outputExt',
        );

        compressed = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          targetPath,
          format: compressFormat,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
          keepExif: false,
        );

        if (compressed == null) {
          quality -= 10;
          continue;
        }

        final compressedSize = await File(compressed.path).length();
        print(
            '[PROFILE] Compression attempt quality=$quality, width=$minWidth, height=$minHeight, size=$compressedSize');

        if (compressedSize <= _maxImageSize) {
          return compressed.path;
        }

        quality -= 10;
        minWidth = (minWidth * 0.9).round().clamp(640, 1920);
        minHeight = (minHeight * 0.9).round().clamp(640, 1920);
      }

      return compressed?.path;
    } catch (e) {
      print('[PROFILE] Compression error: $e');
      return null;
    }
  }

  CompressFormat _getCompressFormat(String ext) {
    switch (ext) {
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg;
    }
  }

  Future<bool> _uploadUserImageToServer(String imagePath) async {
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);
    final ProfileProvider profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    final token = (userProvider.token ?? '').trim();
    final userCd = (profileProvider.data?.userCd ?? '').toString().trim();

    if (token.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Token missing');
      print('[PROFILE] users/image skipped: token is empty');
      return false;
    }

    if (userCd.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(message: 'User code missing');
      print('[PROFILE] users/image skipped: userCd is empty');
      return false;
    }

    final uploadUrl = AppConfig.baseURL + 'users/image';
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        AppSnackBar.showGetXCustomSnackBar(message: 'Selected file not found');
        print(
            '[PROFILE] users/image skipped: file does not exist at $imagePath');
        return false;
      }

      final bytes = await file.readAsBytes();
      var mimeType = lookupMimeType(imagePath, headerBytes: bytes) ?? '';
      if (mimeType == 'image/jpg') {
        mimeType = 'image/jpeg';
      }

      const allowedMimeTypes = {
        'image/jpeg',
        'image/png',
        'image/webp',
      };
      if (!allowedMimeTypes.contains(mimeType)) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Only JPG, PNG, JPEG, WEBP allowed');
        print('[PROFILE] users/image skipped: invalid mimeType=$mimeType');
        return false;
      }

      final mimeParts = mimeType.split('/');
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'x-app-type': 'oms',
      });
      request.fields['userCd'] = userCd;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: p.basename(imagePath),
          contentType: MediaType(mimeParts[0], mimeParts[1]),
        ),
      );

      print(uploadUrl);
      print('Bearer $token');
      print('[PROFILE] users/image mimeType: $mimeType');
      print('[PROFILE] users/image body: userCd=$userCd, file=$imagePath');

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print('[PROFILE] users/image status: ${streamedResponse.statusCode}');
      print(responseBody);

      String message = streamedResponse.statusCode >= 200 &&
              streamedResponse.statusCode < 300
          ? 'Image uploaded successfully'
          : 'Image upload failed';

      if (responseBody.trim().isNotEmpty) {
        try {
          final decoded = json.decode(responseBody);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}
      }

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        AppSnackBar.showGetXCustomSnackBar(
            message: message, backgroundColor: Colors.green);
        return true;
      }

      AppSnackBar.showGetXCustomSnackBar(message: message);
      return false;
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(message: 'Image upload failed');
      print('[PROFILE] users/image error: $e');
      return false;
    }
  }

  void _setData() {
    // No need for setState here if this is called before the first build,
    // as the controllers are being initialized with the correct values.
    // If this method could be called again later to refresh data *after* build,
    // then setState would be necessary.
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);

    _nameClt.text = p.data?.userName ?? 'No User Name';
    _codeClt.text = p.data?.userType ?? 'No User Type';
    _phoneNoClt.text = p.data?.mobileno ?? 'No User Mobile No';
    _emailController.text = 'No Email';
    _existingImageUrl = (p.data?.userImageUrl ?? '').toString().trim();
    _addressClt.text =
        userProvider.syncName ?? "No Company Name"; // Simplified null check
  }

  Future<void> _loadMonthlyTargetAmount() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final currentUserCd =
          (profileProvider.data?.userCd ?? '').toString().trim();
      final currentMonthTarget =
          DateTime(DateTime.now().year, DateTime.now().month, 1);
      final currentMonthTargetText =
          '${currentMonthTarget.year.toString().padLeft(4, '0')}-${currentMonthTarget.month.toString().padLeft(2, '0')}-${currentMonthTarget.day.toString().padLeft(2, '0')}';

      final targets = await _monthlyTargetApiService.fetchMonthlyTargets(
        targetMonth: currentMonthTargetText,
        userCd: currentUserCd,
        token: userProvider.token,
      );

      if (!mounted) {
        return;
      }

      final matchingTargets = targets.where((target) {
        final matchesUser =
            currentUserCd.isEmpty || target.userCd.trim() == currentUserCd;
        final matchesMonth = target.targetMonth.trim().isEmpty ||
            target.targetDate.trim().startsWith(
                '${currentMonthTarget.year.toString().padLeft(4, '0')}-${currentMonthTarget.month.toString().padLeft(2, '0')}');
        return matchesUser &&
            matchesMonth &&
            target.type.toUpperCase() == 'POB';
      }).toList();

      MonthlyTargetItemModel? selectedTarget;
      if (matchingTargets.isNotEmpty) {
        matchingTargets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        selectedTarget = matchingTargets.first;
      } else if (targets.isNotEmpty) {
        final pobTargets = targets
            .where((target) => target.type.toUpperCase() == 'POB')
            .toList();
        if (pobTargets.isNotEmpty) {
          pobTargets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          selectedTarget = pobTargets.first;
        }
      }

      setState(() {
        _monthlyTargetController.text = selectedTarget == null
            ? 'No Monthly Target'
            : Helper.parseNumericValue(
                selectedTarget.salesmanTargetAmount.toStringAsFixed(2));
      });
    } catch (e) {
      print('[PROFILE] Failed to load monthly target amount: $e');
      if (mounted) {
        setState(() {
          _monthlyTargetController.text = 'No Monthly Target';
        });
      }
    }
  }

  // Helper function to check connectivity
  Future<bool> _isConnected() async {
    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();
    // Check if the list contains any of the connected types
    // and does not exclusively contain 'none'.
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.vpn)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // You can access UserProvider here or directly in the onTap callback if preferred.
    // If only used in onTap, accessing it there might be slightly cleaner.
    final ProfileProvider p = context.watch<ProfileProvider>();
    final UserProvider userProvider = context.watch<UserProvider>();
    final existingImageUrl = (_existingImageUrl ?? '').trim().isNotEmpty
        ? (_existingImageUrl ?? '').trim()
        : (p.data?.userImageUrl ?? '').toString().trim();

    // const buildTime = String.fromEnvironment('BUILD_TIME');

    const buildTime = String.fromEnvironment(
      'BUILD_TIME',
      defaultValue: '',
    );

    return Scaffold(
      backgroundColor: Color(0xFFF0F3F2),
      appBar: CustomAppBar(
        title: 'Profile',
        actions: [
          // Consider if this Visibility widget is always true. If so, it can be removed.
          Visibility(
            visible: false,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () async {
                  if (!mounted)
                    return; // Check if the widget is still in the tree

                  if (await _isConnected()) {
                    // Show confirmation dialog
                    final bool? confirmLogout = await showDialog<bool>(
                      // Explicit type
                      context: context,
                      builder: (BuildContext dialogContext) {
                        // Use a different context name
                        return AlertDialog(
                          title: const Text('Confirm Logout'),
                          content:
                              const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext)
                                    .pop(false); // Cancel
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext)
                                    .pop(true); // Confirm
                              },
                              child: const Text('Logout'),
                            ),
                          ],
                        );
                      },
                    );

                    // Proceed with logout if confirmed (and not null)
                    if (confirmLogout == true) {
                      // Explicitly check for true
                      // No need for .then if you're not doing anything after the future completes here
                      await userProvider.userSignout(context);
                      if (!mounted) return;
                      Get.offAll(() => LoginPage());
                    }
                  } else {
                    if (!mounted) return;
                    AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please check your internet connection.');
                  }
                },
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
          ),
          if (buildTime.trim().isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  "Build: $buildTime",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: CommonAppDrawer(
        narrationModuleNo: narrationModuleNo,
        narrationReadRight: narrationReadRight,
        narrationWriteRights: narrationWriteRights,
        narrationUpdateRights: narrationUpdateRights,
        narrationDeleteRight: narrationDeleteRight,
        narrationPrintRights: narrationPrintRights,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Added SingleChildScrollView for longer content
          padding: const EdgeInsets.only(
              top: 15, left: 8, right: 8, bottom: 15), // Added bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _onProfilePhotoTap(existingImageUrl),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: ClipOval(
                      child: _selectedUserImage != null
                          ? Image.file(
                              File(_selectedUserImage!.path),
                              fit: BoxFit.cover,
                            )
                          : (existingImageUrl.isNotEmpty)
                              ? Image.network(
                                  existingImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.camera_alt_outlined,
                                      size: 34,
                                      color: Colors.grey.shade600,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.camera_alt_outlined,
                                  size: 34,
                                  color: Colors.grey.shade600,
                                ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Center(
                child: Text(
                  (_selectedUserImage != null || existingImageUrl.isNotEmpty)
                      ? "Tap to view photo"
                      : "Tap to add image",
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              _buildProfileTextField1(
                controller: _nameClt,
                label: "Name",
                icon: Icons.person,
              ),
              const SizedBox(height: 4),
              _buildProfileTextField1(
                controller: _codeClt,
                label: "User Type",
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 4),
              _buildProfileTextField1(
                controller: _addressClt,
                label: "Company Name",
                icon: Icons.business,
              ),
              const SizedBox(height: 4),
              _buildProfileTextField1(
                controller: _phoneNoClt,
                label: "Phone No",
                icon: Icons.call,
              ),
              const SizedBox(height: 4),
              _buildProfileTextField1(
                controller: _emailController,
                label: "Email",
                icon: Icons.mail_outline_outlined,
              ),
              if (p.data != null &&
                  p.data!.modulesList!.any((module) =>
                      module.mODULENO == "236" &&
                      module.rEADRIGHT == true)) ...[
                const SizedBox(height: 4),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.track_changes_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Monthly Target",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _monthlyTargetController.text,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final text = _monthlyTargetController.text.trim();
                          final isEmpty = text.isEmpty ||
                              text.toLowerCase() == 'no monthly target';

                          if (isEmpty) {
                            await Get.to(() => const MonthlyTargetView());
                          } else {
                            await Get.to(() => const EditMonthlyTargetView());
                          }

                          if (mounted) {
                            await _loadMonthlyTargetAmount();
                          }
                        },
                        icon: Icon(
                          (_monthlyTargetController.text.trim().isEmpty ||
                                  _monthlyTargetController.text
                                          .trim()
                                          .toLowerCase() ==
                                      'no monthly target')
                              ? Icons.add_circle_outline
                              : Icons.edit_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(
                  top: 30.0,
                  left: 9,
                  right: 9,
                ), // Increased top padding
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Color(0xFFC53232),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12), // Added padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              8), // Match card's border radius
                        ),
                      ),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context,
                            userProvider); // Pass userProvider if needed for deletion
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          Text(
                            "Delete Account",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
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

  // Helper widget to reduce repetition for TextFormFields
  Widget _buildProfileTextField({
    required TextEditingController controller,
    required String label,
    Icon? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 8.0, horizontal: 8.0), // Consistent padding
      child: Container(
        child: TextFormField(
          readOnly: true,
          controller: controller,
          decoration: InputDecoration(
            label: Text(label),
            focusedBorder: const OutlineInputBorder(), // Use const
            enabledBorder: const OutlineInputBorder(), // Use const
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTextField1({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    Color? labelIconBg,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: labelIconBg ?? Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.blue,
              ),
            ),
          if (icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: const TextSelectionThemeData(
                      selectionColor: Color(0xFF5ECCFF), // Highlight color
                      selectionHandleColor: Colors.blue, // Handle color
                    ),
                  ),
                  child: SelectableText(
                    controller.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, UserProvider userProvider) {
    showDialog<void>(
      // Explicit type
      context: context,
      builder: (BuildContext dialogContext) {
        // Use a different context name
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: const Text(
              "Are you sure you want to delete your account? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                // Make async if service call is async
                if (!mounted) return;
                // Call the delete account service
                // Assuming Services().deleteAccount might also need context or user info
                await Services().deleteAccount(
                    context /*, other params if needed, e.g., userProvider.user.id */);
                if (!mounted) return;
                Navigator.of(dialogContext).pop(); // Close the dialog FIRST
                Get.offAll(() => LoginPage()); // Then navigate
              },
            ),
          ],
        );
      },
    );
  }

  // This function seems unused now. If you re-introduce it,
  // ensure to update the connectivity check and use 'userProvider'
  // which you'd need to pass or access via Provider.of.
  // ignore: unused_element
  void _showLogoutConfirmationDialog_Unused(
      BuildContext context, UserProvider userProvider) async {
    if (!mounted) return;

    if (await _isConnected()) {
      final bool? confirmLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Confirm Logout"),
            content: const Text("Are you sure you want to log out?"),
            actions: <Widget>[
              TextButton(
                child: const Text("No"),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              TextButton(
                child: const Text("Yes", style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (confirmLogout == true) {
        await userProvider.userSignout(context);
        if (!mounted) return;
        Get.offAll(() => LoginPage());
      }
    } else {
      if (!mounted) return;
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please check your internet connection.');
    }
  }
}

class _ProfilePhotoPreviewScreen extends StatelessWidget {
  final String? localImagePath;
  final String networkImageUrl;

  const _ProfilePhotoPreviewScreen({
    required this.localImagePath,
    required this.networkImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocal =
        localImagePath != null && localImagePath!.trim().isNotEmpty;
    final hasNetwork = networkImageUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Profile Photo'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: hasLocal
                      ? Image.file(File(localImagePath!), fit: BoxFit.contain)
                      : hasNetwork
                          ? Image.network(
                              networkImageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.white70,
                                  size: 60,
                                );
                              },
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 90,
                            ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.edit),
                label: const Text('Change Photo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoEditorScreen extends StatefulWidget {
  final String imagePath;

  const _ProfilePhotoEditorScreen({required this.imagePath});

  @override
  State<_ProfilePhotoEditorScreen> createState() =>
      _ProfilePhotoEditorScreenState();
}

class _ProfilePhotoEditorScreenState extends State<_ProfilePhotoEditorScreen> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _repaintKey = GlobalKey();

  int _quarterTurns = 0;
  bool _saving = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _saveEditedPhoto() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final renderObject = _repaintKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        if (mounted) {
          AppSnackBar.showGetXCustomSnackBar(message: 'Unable to edit image');
        }
        return;
      }

      final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          AppSnackBar.showGetXCustomSnackBar(message: 'Unable to edit image');
        }
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(
        tempDir.path,
        'profile_edit_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(outputPath).writeAsBytes(bytes, flush: true);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(outputPath);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showGetXCustomSnackBar(message: 'Unable to edit image');
      }
      print('[PROFILE] Photo editor error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop & Rotate'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveEditedPhoto,
            child: Text(
              _saving ? 'Saving...' : 'Done',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double side = math.min(
                      constraints.maxWidth - 24, constraints.maxHeight - 24);

                  return Center(
                    child: Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                      ),
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 1,
                            maxScale: 5,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: RotatedBox(
                              quarterTurns: _quarterTurns,
                              child: Image.file(
                                File(widget.imagePath),
                                width: side,
                                height: side,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quarterTurns = (_quarterTurns + 3) % 4;
                      });
                    },
                    icon: const Icon(Icons.rotate_left, color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _quarterTurns = 0;
                        _transformController.value = Matrix4.identity();
                      });
                    },
                    child: const Text('Reset',
                        style: TextStyle(color: Colors.white)),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _quarterTurns = (_quarterTurns + 1) % 4;
                      });
                    },
                    icon: const Icon(Icons.rotate_right, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
