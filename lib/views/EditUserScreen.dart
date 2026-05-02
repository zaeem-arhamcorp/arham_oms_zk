import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/person_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/personModal.dart';
import '../providers/user_provider.dart';

class EditUserScreen extends StatefulWidget {
  final int screenId;
  final DatumPerson? data;

  const EditUserScreen({super.key, required this.screenId, this.data});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  static const int _maxImageSize = 2 * 1024 * 1024;

  TextEditingController userCdClt = TextEditingController();
  TextEditingController passwordClt = TextEditingController();
  TextEditingController userNameClt = TextEditingController();
  TextEditingController mobileNumberClt = TextEditingController();
  TextEditingController emailClt = TextEditingController();
  TextEditingController moduleSearchClt = TextEditingController();

  final ImagePicker _userImagePicker = ImagePicker();
  XFile? _selectedUserImage;
  String? _existingImageUrl;

  FocusNode userCdFocusNode = FocusNode();
  FocusNode passwordFocusNode = FocusNode();
  FocusNode userNameFocusNode = FocusNode();
  FocusNode mobileNumberFocusNode = FocusNode();
  FocusNode emailFocusNode = FocusNode();

  bool activeuser = false;
  Role? selectRole;
  List role = [
    Role(id: "M", value: "Master User"),
    Role(id: "O", value: "Operator User"),
  ];

  List<DatumModules> modules = [];
  List<DatumModules> filterModules = [];
  List<dynamic> selectModules = [];

  List<Map<String, dynamic>> firmList = [];
  List<String> selectedFirmIds = [];
  List<String> selectedFirmNames = [];
  bool allowWebAccess = false;
  bool isLoading = true; // Indicates loading state

  bool _resolveWebAccess(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value.toInt() == 1;

    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  getModules() {
    Services().getModules(context).then((value) {
      setState(() {
        modules.addAll(value?.data ?? []);
        if (widget.screenId != 0) {
          filterModules = modules.where((m) {
            if (m.aPPTYPE.toString().trim().toUpperCase() == "OMS") {
              // Only allow OMSReport modules with matching role
              return m.moduleType == "OMSReport" ||
                  m.moduleType == "Transaction" &&
                      m.role.contains(selectRole!.id);
            } else {
              // For Master & Transaction â†’ always include
              return (m.moduleType == "Master" ||
                      m.moduleType == "Transaction") &&
                  m.role.contains(selectRole!.id);
            }
          }).toList();

          // filterModules = selectRole == "OMS"
          //     ? modules.where((element) => element.role.contains(selectRole!.id)).toList()
          //     : modules;
        }
      });
    });
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
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Select from Files'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    final path = result.files.first.path;
                    if (path != null && path.isNotEmpty) {
                      await _handleUserImage(path);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onUserPhotoTap() async {
    final hasPhoto = (_selectedUserImage != null) ||
        ((_existingImageUrl ?? '').toString().trim().isNotEmpty);

    if (!hasPhoto) {
      await _pickUserImage();
      return;
    }

    final shouldEdit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditUserPhotoPreviewScreen(
          localImagePath: _selectedUserImage?.path,
          networkImageUrl: (_existingImageUrl ?? '').toString(),
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
        builder: (_) => _EditUserPhotoEditorScreen(imagePath: imagePath),
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
  }

  Future<String?> _compressImageToUnder2Mb(
      String sourcePath, String ext) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        print('[EditUserScreen] Compression skipped: source file missing');
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
          'edit_user_${DateTime.now().millisecondsSinceEpoch}_$quality.$outputExt',
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
            '[EditUserScreen] Compression attempt quality=$quality, width=$minWidth, height=$minHeight, size=$compressedSize');

        if (compressedSize <= _maxImageSize) {
          return compressed.path;
        }

        quality -= 10;
        minWidth = (minWidth * 0.9).round().clamp(640, 1920);
        minHeight = (minHeight * 0.9).round().clamp(640, 1920);
      }

      return compressed?.path;
    } catch (e) {
      print('[EditUserScreen] Compression error: $e');
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

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final regex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
    return regex.hasMatch(trimmed);
  }

  @override
  void initState() {
    super.initState();
    firmAPI();
    getModules();

    if (widget.screenId != 0) {
      setData();
    }
  }

  @override
  void dispose() {
    // Dispose of the focus nodes
    userCdFocusNode.dispose();
    passwordFocusNode.dispose();
    userNameFocusNode.dispose();
    mobileNumberFocusNode.dispose();
    emailFocusNode.dispose();
    super.dispose();
  }

  setData() {
    setState(() {
      userCdClt.text = widget.data!.userCd;
      userNameClt.text = widget.data!.userName;
      allowWebAccess = _resolveWebAccess(widget.data?.type);
      //passwordClt.text = widget.data!.userPwd;
      activeuser = !widget.data!.blacklist;
      mobileNumberClt.text = widget.data!.mobileno ?? "";
      emailClt.text = widget.data!.email ?? "";
      _existingImageUrl = widget.data?.userImageUrl;
      selectRole =
          role.firstWhere((element) => element.id == widget.data!.userType);
      //selectModules = widget.data!.moduleNos;

      //TODO : OLD COMPARE
      // if (widget.data != null && widget.data!.modules is List) {
      //   selectModules = (widget.data!.modules as List<dynamic>)
      //       .map((e) {
      //         if (e is Map && e.containsKey('MODULE_NO')) {
      //           return e['MODULE_NO'].toString(); // Ensure consistent padding
      //         }
      //         return ''; // Return an empty string if 'FIRM_ID' is not found
      //       })
      //       .where((id) => id.isNotEmpty)
      //       .toList();
      //
      //   print("Edit TIme Modules ID" + selectModules.toString());
      //   print("Edit TIme Modules Users" + widget.data!.modules.toString());
      // }

      //TODO : AS PER NEW CHANGES
      if (widget.data != null && widget.data!.modules is List) {
        selectModules = (widget.data!.modules as List<dynamic>)
            .map((e) {
              if (e is Map) {
                return {
                  'moduleNo': e['MODULE_NO'].toString(),
                  // Ensure consistent padding
                  'readRight': e['READ_RIGHT'] ?? false,
                  'writeRight': e['WRITE_RIGHT'] ?? false,
                  'updateRight': e['UPDATE_RIGHT'] ?? false,
                  'deleteRight': e['DELETE_RIGHT'] ?? false,
                  'printRight': e['PRINT_RIGHT'] ?? false,
                };
              }
              return {}; // Return an empty map if not a Map
            })
            .where((module) => module.isNotEmpty) // Filter out empty maps
            .toList();

        print("Edit Time Modules ID: ${selectModules.toString()}");
        print("Edit Time Modules Users: ${widget.data!.modules.toString()}");
      }

      // if (widget.data != null && widget.data!.firmUsers is List) {
      //   selectedFirmIds = (widget.data!.firmUsers as List<dynamic>)
      //       .map((e) => e.toString())
      //       .toList();
      // }

      if (widget.data != null && widget.data!.firmUsers is List) {
        selectedFirmIds = (widget.data!.firmUsers as List<dynamic>)
            .map((e) {
              // Extract only the 'FIRM_ID' from each element
              if (e is Map && e.containsKey('FIRM_ID')) {
                return e['FIRM_ID'].toString(); // Ensure consistent padding
              }
              return ''; // Return an empty string if 'FIRM_ID' is not found
            })
            .where((id) =>
                id.isNotEmpty) // Filter out invalid entries (empty strings)
            .toList();

        // print("Edit TIme Firm ID"+selectedFirmIds.toString());
        // print("Edit TIme Firm Users"+widget.data!.firmUsers.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final PersonProvider person = context.watch<PersonProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: widget.screenId == 0 ? "Add User" : "Update User",
      ),
      body: SafeArea(
        child: Container(
          height: size.height,
          width: size.width,
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.all(10),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _onUserPhotoTap,
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
                              : (_existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty)
                                  ? Image.network(
                                      _existingImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                    height: 8.h,
                  ),
                  Center(
                    child: Text(
                      (_selectedUserImage != null ||
                              ((_existingImageUrl ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty))
                          ? "Tap to view image"
                          : "Tap to add image",
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    height: 10.h,
                  ),
                  if (widget.screenId == 0)
                    UserTextField(
                      action: TextInputAction.next,
                      clt: userCdClt,
                      hint: "User Code",
                      type: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  SizedBox(
                    height: 5.h,
                  ),
                  UserTextField(
                    action: TextInputAction.next,
                    clt: passwordClt,
                    hint: "Reset Password",
                    maxLength: 10,
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  UserTextField(
                    action: TextInputAction.next,
                    clt: userNameClt,
                    hint: "User Name",
                    maxLength: 40,
                    inputFormatters: [
                      StartWithAlphabetOrUnderscoreFormatter(),
                    ],
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  UserTextField(
                    action: TextInputAction.done,
                    clt: mobileNumberClt,
                    hint: "Mobile No",
                    type: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  UserTextField(
                    action: TextInputAction.done,
                    clt: emailClt,
                    hint: "Email",
                    type: TextInputType.emailAddress,
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text("Active User:"),
                      SizedBox(
                        height: 5.h,
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 8, right: 8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Color.fromRGBO(189, 189, 189, 100)),
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Is Active User",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 15.sp),
                            ),
                            CupertinoSwitch(
                                value: activeuser,
                                onChanged: (val) {
                                  setState(() {
                                    activeuser = val;
                                  });
                                }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  Container(
                    padding: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: Color.fromRGBO(189, 189, 189, 100)),
                        borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton2(
                        hint: Text('Select User Type',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 15.sp)),
                        items: role
                            .map((item) => DropdownMenuItem<Role>(
                                  value: item,
                                  child: Text(
                                    item.value,
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                        value: selectRole,
                        onChanged: (value) {
                          setState(() {
                            selectRole = value;
                            filterModules = modules.where((m) {
                              if (m.aPPTYPE.toString().trim().toUpperCase() ==
                                  "OMS") {
                                // Only allow OMSReport modules with matching role
                                return m.moduleType == "OMSReport" ||
                                    m.moduleType == "Transaction" &&
                                        m.role.contains(selectRole!.id);
                              } else {
                                // For Master & Transaction â†’ always include
                                return (m.moduleType == "Master" ||
                                        m.moduleType == "Transaction") &&
                                    m.role.contains(selectRole!.id);
                              }
                            }).toList();
                            // filterModules = modules
                            //     .where((element) =>
                            //         element.role.contains(selectRole!.id))
                            //     .toList();
                          });
                        },
                      ),
                    ),
                  ),
                  isLoading
                      ? Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0.0, vertical: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _showMultiSelectDialog,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: Colors.grey, width: 1.0),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          selectedFirmNames.isEmpty
                                              ? 'Select Firms'
                                              : selectedFirmNames.join(' | '),
                                          maxLines: null,
                                          overflow: TextOverflow.visible,
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down,
                                          color: Colors.black),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Checkbox(
                                    value: allowWebAccess,
                                    onChanged: (value) {
                                      setState(() {
                                        allowWebAccess = value ?? false;
                                      });
                                    },
                                  ),
                                  const Text("Allow Web Access"),
                                ],
                              ),
                            ],
                          ),
                        ),
                  SizedBox(
                    height: 5.h,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text("Modules:"),
                      ),
                      if (modules.length == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text("Loading...."),
                        ),
                      if (modules.length != 0 && selectRole == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text("Please Select the role"),
                        )
                      else if (modules.length != 0 && selectRole != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            // Search bar
                            TextField(
                              controller: moduleSearchClt,
                              onChanged: (value) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: "Search modules...",
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: moduleSearchClt.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            moduleSearchClt.clear();
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                            SizedBox(height: 12),
                            // DefaultTabController wrapping TabBar and TabBarView
                            DefaultTabController(
                              length: 3,
                              child: Column(
                                children: [
                                  // TabBar
                                  TabBar(
                                    tabs: [
                                      Tab(
                                        child: Text(
                                          "Master (${_getFilteredModulesByType("Master").length})",
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Tab(
                                        child: Text(
                                          "Transaction (${_getFilteredModulesByType("Transaction").length})",
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Tab(
                                        child: Text(
                                          "Report (${_getFilteredModulesByType("OMSReport").length})",
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),
                                  // TabBarView
                                  SizedBox(
                                    height: 500,
                                    child: TabBarView(
                                      physics: NeverScrollableScrollPhysics(),
                                      children: [
                                        // Master Tab
                                        _buildModuleListContent(
                                            _getFilteredModulesByType(
                                                "Master")),
                                        // Transaction Tab
                                        _buildModuleListContent(
                                            _getFilteredModulesByType(
                                                "Transaction")),
                                        // Report Tab
                                        _buildModuleListContent(
                                            _getFilteredModulesByType(
                                                "OMSReport")),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  GestureDetector(
                    onTap: () {
                      final email = emailClt.text.trim();

                      if (userNameClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user name");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user name");
                      } else if (userCdClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user code");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user code");
                      }
                      // else if (passwordClt.text.isEmpty) {
                      //   //Fluttertoast.showToast(msg: "Please enter user password");
                      //   AppSnackBar.showGetXCustomSnackBar(
                      //       message: "Please enter user password");
                      // }
                      else if (mobileNumberClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user phone no");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user phone no");
                      } else if (mobileNumberClt.text.isNotEmpty &&
                          mobileNumberClt.text.length != 10) {
                        //Fluttertoast.showToast(msg: "Please enter user 10 digit phone no");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user 10 digit phone no");
                      } else if (email.isNotEmpty && !_isValidEmail(email)) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter valid email address");
                      } else if (selectRole == null) {
                        //Fluttertoast.showToast(msg: "Please select user role");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please select user role");
                      } else if (selectedFirmIds.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please select firm");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please select firm");
                      } else {
                        person.changeLoading(true);
                        if (widget.screenId == 0) {
                          person
                              .addPerson(
                                  context,
                                  userNameClt.text,
                                  userCdClt.text,
                                  passwordClt.text,
                                  mobileNumberClt.text,
                                  selectRole!.id,
                                  !activeuser,
                                  selectModules,
                                  selectedFirmIds,
                                  email,
                                  sendWebType: allowWebAccess,
                                  imagePath: _selectedUserImage?.path)
                              .then((value) {
                            person.changeLoading(false);
                            if (value == true) {
                              Get.back(result: 1);
                            }
                          });
                        } else {
                          final String updateUserUrl =
                              AppConfig.baseURL + "users";
                          final String userImageUrl =
                              AppConfig.baseURL + "users/image";

                          print("[EditUserScreen] Update User button clicked");
                          print("[EditUserScreen] API URL: $updateUserUrl");
                          print(
                              "[EditUserScreen] Image API URL: $userImageUrl");
                          print(
                              "[EditUserScreen] Image selected: ${_selectedUserImage?.path != null}");

                          person
                              .updatePerson(
                                  context,
                                  userNameClt.text,
                                  userCdClt.text,
                                  passwordClt.text,
                                  mobileNumberClt.text,
                                  selectRole!.id,
                                  !activeuser,
                                  selectModules,
                                  selectedFirmIds,
                                  email,
                                  sendWebType: allowWebAccess,
                                  imagePath: _selectedUserImage?.path)
                              .then((value) {
                            print(value);
                            person.changeLoading(false);
                            if (value == true) {
                              Get.back(result: 1);
                            }
                          });
                        }
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(15),
                      width: size.width,
                      decoration: BoxDecoration(color: Color(0XFF2c9ed9)),
                      child: Text(
                        widget.screenId == 0 ? "Add User" : "Update User",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              Visibility(
                  visible: person.loading,
                  child: Container(
                      decoration:
                          BoxDecoration(color: Colors.grey.withOpacity(0.5)),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppConfig.mainColor,
                        ),
                      )))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightCheckbox(
    String moduleNo,
    String label, [
    String? rightField,
    String? rightField2,
    String? rightField3,
    String? rightField4,
    String? rightField5,
  ]) {
    return Row(
      mainAxisSize:
          MainAxisSize.min, // Makes the Row take minimum required space
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          // Wraps Checkbox in Flexible to allow shrinking if needed
          child: Checkbox(
            value: _isRightChecked(moduleNo, label, rightField, rightField2,
                rightField3, rightField4, rightField5),
            onChanged: (value) {
              setState(() {
                if (label == "All") {
                  // When 'All' checkbox is clicked, set all rights to the same value
                  var module = selectModules.firstWhere(
                      (element) => element['moduleNo'] == moduleNo,
                      orElse: () => {});
                  if (module.isNotEmpty) {
                    module[rightField] = value ?? false;
                    module[rightField2] = value ?? false;
                    module[rightField3] = value ?? false;
                    module[rightField4] = value ?? false;
                    module[rightField5] = value ?? false;
                  } else {
                    selectModules.add({
                      'moduleNo': moduleNo,
                      'readRight': value ?? false,
                      'writeRight': value ?? false,
                      'updateRight': value ?? false,
                      'deleteRight': value ?? false,
                      'printRight': value ?? false,
                    });
                  }
                } else {
                  // When any specific checkbox is clicked, just update that right
                  var module = selectModules.firstWhere(
                      (element) => element['moduleNo'] == moduleNo,
                      orElse: () => {});
                  if (module.isNotEmpty) {
                    module[rightField] = value ?? false;
                  } else {
                    selectModules.add({
                      'moduleNo': moduleNo,
                      'readRight': false,
                      'writeRight': false,
                      'updateRight': false,
                      'deleteRight': false,
                      'printRight': false,
                    });
                    module = selectModules.firstWhere(
                        (element) => element['moduleNo'] == moduleNo);
                    module[rightField] = value ?? false;
                  }
                }

                // After updating, check if any specific checkbox is unchecked and uncheck "All"
                _removeModuleIfUnchecked(moduleNo);

                print(selectModules);
              });
            },
            materialTapTargetSize:
                MaterialTapTargetSize.shrinkWrap, // Reduces the tap target size
            visualDensity:
                VisualDensity.compact, // Makes the checkbox more compact
          ),
        ),
        if (label.isNotEmpty) // Only show if label is not empty
          Visibility(
            visible: false,
            maintainSize: false, // Prevents taking space when invisible
            child: Text(label,
                overflow: TextOverflow.ellipsis), // Handles text overflow
          ),
      ],
    );
  }

// Function to check if the "All" checkbox should be checked
  bool _isRightChecked(
    String moduleNo,
    String label,
    String? rightField,
    String? rightField2,
    String? rightField3,
    String? rightField4,
    String? rightField5,
  ) {
    if (label == "All") {
      // Check if all rights are selected for the module
      var module = selectModules.firstWhere(
          (element) => element['moduleNo'] == moduleNo,
          orElse: () => {});
      if (module.isNotEmpty) {
        return module['readRight'] == true &&
            module['writeRight'] == true &&
            module['updateRight'] == true &&
            module['deleteRight'] == true &&
            module['printRight'] == true;
      }
      return false;
    } else {
      // Check for individual rights
      var module = selectModules.firstWhere(
          (element) => element['moduleNo'] == moduleNo,
          orElse: () => {});
      if (module.isNotEmpty) {
        return module[rightField] == true;
      }
      return false;
    }
  }

// Function to remove a module from the list if all rights are unchecked
  void _removeModuleIfUnchecked(String moduleNo) {
    var module = selectModules.firstWhere(
      (element) => element['moduleNo'] == moduleNo,
      orElse: () => {},
    );

    if (module.isNotEmpty) {
      // Check if all rights are unchecked
      if (module['readRight'] == false &&
          module['writeRight'] == false &&
          module['updateRight'] == false &&
          module['deleteRight'] == false &&
          module['printRight'] == false) {
        // If all rights are unchecked, remove the module from the list
        selectModules.removeWhere((element) => element['moduleNo'] == moduleNo);
      }
    }
  }

  // Helper method to get modules filtered by type and search term
  List<DatumModules> _getFilteredModulesByType(String moduleType) {
    final searchTerm = moduleSearchClt.text.trim().toLowerCase();
    return filterModules.where((module) {
      final typeMatch = module.moduleType == moduleType;
      final searchMatch = searchTerm.isEmpty ||
          module.moduleName.toLowerCase().contains(searchTerm);
      return typeMatch && searchMatch;
    }).toList();
  }

  // Widget builder for module list content
  Widget _buildModuleListContent(List<DatumModules> modulesList) {
    if (modulesList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text("No modules found"),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  "Module Name",
                  style: TextStyle(fontSize: 14.0),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "All",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "View",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Add",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Edit",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Delete",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Print",
                    style: TextStyle(fontSize: 14.0),
                  ),
                ),
              ),
            ],
          ),
          Divider(),
          ListView.builder(
            itemCount: modulesList.length,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) {
              bool isReportModule = modulesList[i].moduleType == 'OMSReport';

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "${modulesList[i].moduleName}",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: !isReportModule,
                                child: _buildRightCheckbox(
                                  modulesList[i].moduleNo,
                                  "All",
                                  "readRight",
                                  "writeRight",
                                  "updateRight",
                                  "deleteRight",
                                  "printRight",
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildRightCheckbox(
                                modulesList[i].moduleNo,
                                "View",
                                "readRight",
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: !isReportModule,
                                child: _buildRightCheckbox(
                                  modulesList[i].moduleNo,
                                  "Add",
                                  "writeRight",
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: !isReportModule,
                                child: _buildRightCheckbox(
                                  modulesList[i].moduleNo,
                                  "Edit",
                                  "updateRight",
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Visibility(
                                visible: !isReportModule,
                                child: _buildRightCheckbox(
                                  modulesList[i].moduleNo,
                                  "Delete",
                                  "deleteRight",
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildRightCheckbox(
                                modulesList[i].moduleNo,
                                "Print",
                                "printRight",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> firmAPI() async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    final url =
        Uri.parse(AppConfig.baseURL + 'firm'); // Replace with your API URL

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("Bearer ${ub.token}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          firmList = firms.map((item) {
            return {
              "firmName":
                  item['FIRM_NAME']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                      'Unnamed Firm',
              "firmId": item['FIRM_ID'],
            };
          }).toList();

          // Pre-fill selectedFirmNames based on selectedFirmIds
          selectedFirmNames = firmList
              .where(
                  (firm) => selectedFirmIds.contains(firm['firmId'].toString()))
              .map((firm) => firm['firmName'] as String)
              .toList();

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showMultiSelectDialog() async {
    // Temporary list to hold selections
    final List<String> tempSelectedIds = List.from(selectedFirmIds);
    print("Open Dialog" + tempSelectedIds.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update the dialog's UI
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Select Firms'),
              content: SingleChildScrollView(
                child: Column(
                  children: firmList.map((firm) {
                    // Ensure consistent formatting for firmSyncId
                    final String firmSyncId = firm['firmId'].toString();
                    return CheckboxListTile(
                      value: tempSelectedIds.contains(firmSyncId),
                      title: Text(firm['firmName']),
                      onChanged: (bool? isChecked) {
                        setDialogState(() {
                          // Update dialog UI without affecting the main state
                          if (isChecked == true) {
                            if (!tempSelectedIds.contains(firmSyncId)) {
                              tempSelectedIds.add(firmSyncId);
                            }
                          } else {
                            tempSelectedIds.remove(firmSyncId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                        context); // Close dialog without saving changes
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Update main state only when user confirms
                      selectedFirmIds = List.from(tempSelectedIds);
                      selectedFirmNames = firmList
                          .where((firm) => selectedFirmIds
                              .contains(firm['firmId'].toString()))
                          .map((firm) => firm['firmName'] as String)
                          .toList();

                      // Debugging
                      print(
                          'Selected Firm IDs: $selectedFirmIds'); // Outputs the IDs
                      print(
                          'Selected Firm Names: $selectedFirmNames'); // Outputs the Names
                    });
                    Navigator.pop(context); // Close dialog
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EditUserPhotoPreviewScreen extends StatelessWidget {
  final String? localImagePath;
  final String networkImageUrl;

  const _EditUserPhotoPreviewScreen({
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
        title: const Text('User Photo'),
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

class _EditUserPhotoEditorScreen extends StatefulWidget {
  final String imagePath;

  const _EditUserPhotoEditorScreen({required this.imagePath});

  @override
  State<_EditUserPhotoEditorScreen> createState() =>
      _EditUserPhotoEditorScreenState();
}

class _EditUserPhotoEditorScreenState
    extends State<_EditUserPhotoEditorScreen> {
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
        'edit_user_photo_${DateTime.now().millisecondsSinceEpoch}.png',
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
      print('[EditUserScreen] Photo editor error: $e');
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

// class UserTextField extends StatefulWidget {
//   const UserTextField({
//     super.key,
//     required this.clt,
//     required this.hint,
//     this.type,
//     this.maxLength,
//   });
//
//   final TextEditingController clt;
//   final String hint;
//   final TextInputType? type;
//   final int? maxLength;
//
//   @override
//   _UserTextFieldState createState() => _UserTextFieldState();
// }
//
// class _UserTextFieldState extends State<UserTextField> {
//   int currentLength = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     // Initialize currentLength with existing text length
//     currentLength = widget.clt.text.length;
//     widget.clt.addListener(() {
//       setState(() {
//         currentLength = widget.clt.text.length;
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.start,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 5.h),
//         TextField(
//           controller: widget.clt,
//           keyboardType: widget.type,
//           inputFormatters: [
//             if (widget.maxLength != null)
//               LengthLimitingTextInputFormatter(widget.maxLength),
//             if (widget.hint == "Mobile No") ...[
//               FilteringTextInputFormatter.digitsOnly,
//               FilteringTextInputFormatter.allow(RegExp(r'^[6-9][0-9]{0,9}$')),
//             ],
//           ],
//           decoration: InputDecoration(
//             labelText: widget.hint,
//             // Show length only if maxLength is provided
//             suffixText: widget.maxLength != null
//                 ? "$currentLength/${widget.maxLength}"
//                 : null,
//             suffixStyle: TextStyle(color: Colors.grey, fontSize: 12),
//             border: OutlineInputBorder(),
//             focusedBorder: OutlineInputBorder(
//               borderSide: BorderSide(color: Colors.red, width: 2.0),
//               borderRadius: BorderRadius.circular(8.0),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

class UserTextField extends StatefulWidget {
  const UserTextField({
    super.key,
    required this.clt,
    required this.hint,
    this.type,
    this.action,
    this.maxLength,
    this.inputFormatters, // <--- added
  });

  final TextEditingController clt;
  final String hint;
  final TextInputType? type;
  final TextInputAction? action;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters; // <--- added

  @override
  _UserTextFieldState createState() => _UserTextFieldState();
}

class _UserTextFieldState extends State<UserTextField> {
  int currentLength = 0;
  late final VoidCallback _textListener;

  @override
  void initState() {
    super.initState();

    currentLength = widget.clt.text.length;
    _textListener = () {
      if (!mounted) return;
      setState(() {
        currentLength = widget.clt.text.length;
      });
    };

    widget.clt.addListener(_textListener);
  }

  @override
  void dispose() {
    widget.clt.removeListener(_textListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        TextField(
          textInputAction: widget.action,
          controller: widget.clt,
          keyboardType: widget.type,

          /// Use ONLY formatters passed by constructor
          inputFormatters: [
            if (widget.maxLength != null)
              LengthLimitingTextInputFormatter(widget.maxLength),

            // If user passed custom formatters â†’ add them
            ...?widget.inputFormatters,
          ],

          decoration: InputDecoration(
            labelText: widget.hint,
            suffixText: widget.maxLength != null
                ? "$currentLength/${widget.maxLength}"
                : null,
            suffixStyle: TextStyle(color: Colors.grey, fontSize: 12),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.0),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }
}

class Role {
  String id;
  String value;

  Role({required this.id, required this.value});
}
