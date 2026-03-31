import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/bottomnavebar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class CreateExpenseRequest extends StatefulWidget {
  const CreateExpenseRequest({super.key});

  @override
  State<CreateExpenseRequest> createState() => _CreateExpenseRequestState();
}

class _CreateExpenseRequestState extends State<CreateExpenseRequest> {
  final _formKey = GlobalKey<FormState>();

  static const int maxImageSize = 2 * 1024 * 1024; // 2MB
  static const int maxDocSize = 5 * 1024 * 1024; // 5MB

  static const String _reimbursementModuleNo = '231';

  // Daily Allowance
  final _dailyAmountController = TextEditingController();
  final _dailyNotesController = TextEditingController();
  final _dailyImagePicker = ImagePicker();
  XFile? _dailyImageFile;
  PlatformFile? _dailyDoc;

  // Other Allowance
  final _otherAmountController = TextEditingController();
  final _otherNotesController = TextEditingController();
  final _otherImagePicker = ImagePicker();
  XFile? _otherImage;
  PlatformFile? _otherDoc;

  DateTime _selectedDate = DateTime.now();
  Set<String> _selectedExpenseTypes = {};
  bool _isSubmitting = false;

  static const String _createExpenseEndpoint = 'users/reimbursements';

  static const List<String> _expenseTypes = <String>[
    'DAILY_ALLOWANCE',
    'OTHER_ALLOWANCE',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[Reimbursement][Create] Screen initialized');
    _selectedExpenseTypes.add('DAILY_ALLOWANCE');
    debugPrint('CreateExpenseRequest: initState called');
    log('CreateExpenseRequest: initState called');
  }

  @override
  void dispose() {
    _dailyAmountController.dispose();
    _dailyNotesController.dispose();
    _otherAmountController.dispose();
    _otherNotesController.dispose();
    super.dispose();
    debugPrint('CreateExpenseRequest: dispose called');
    log('CreateExpenseRequest: dispose called');
  }

  Future<File?> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();

    final targetPath = p.join(
      dir.path,
      "${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 60,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (result == null) return null;

    return File(result.path); // ✅ convert XFile → File
  }

  Future<void> _pickDocDaily() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      if (file.path != null) {
        final size = await File(file.path!).length();

        if (size > maxDocSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Document must be less than 5MB"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _dailyDoc = file;
      });
      debugPrint('Picked document for Daily Allowance: ${file.name}');
      log('Picked document for Daily Allowance: ${file.name}');
    }
  }

  Future<void> _pickDocOther() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      if (file.path != null) {
        final size = await File(file.path!).length();

        if (size > maxDocSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Document must be less than 5MB"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _otherDoc = file;
      });
      debugPrint('Picked document for Other Allowance: ${file.name}');
      log('Picked document for Other Allowance: ${file.name}');
    }
  }

  Future<void> _pickDate() async {
    debugPrint('[Reimbursement][Create] Opening date picker');
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
      debugPrint(
        '[Reimbursement][Create] Date selected: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
      );
    }
  }

  // Future<void> _pickImageDailyAllowance() async {
  //   final XFile? image =
  //       await _dailyImagePicker.pickImage(source: ImageSource.gallery);
  //
  //   if (image == null) return;
  //
  //   final allowed = ['jpg', 'jpeg', 'png', 'webp'];
  //   final ext = image.path.split('.').last.toLowerCase();
  //
  //   if (!allowed.contains(ext)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Only JPG, JPEG, PNG, WEBP allowed"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() {
  //     _dailyImageFile = image;
  //   });
  // }

  Future<void> _handleDailyImage(XFile? image) async {
    if (image == null) return;

    final allowed = ['jpg', 'jpeg', 'png', 'webp'];
    final ext = image.path.split('.').last.toLowerCase();

    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only JPG, PNG, JPEG, WEBP allowed")),
      );
      return;
    }

    File file = File(image.path);

    // Compress
    final compressed = await _compressImage(file);

    // fallback if compression fails
    final finalFile = compressed ?? file;

    final size = await finalFile.length();

    if (size > maxImageSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Image must be less than 2MB"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint("Picked image path: ${image.path}");
    debugPrint("Extension: $ext");
    debugPrint("Final file path: ${finalFile.path}");
    debugPrint("Final size: $size");

    setState(() {
      _dailyImageFile = XFile(finalFile.path);
    });
  }

  Future<void> _pickImageDailyAllowance() async {
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
                  final image = await _dailyImagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  _handleDailyImage(image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Select from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _dailyImagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  _handleDailyImage(image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Future<void> _pickImageOtherAllowance() async {
  //   final XFile? image =
  //       await _otherImagePicker.pickImage(source: ImageSource.gallery);
  //
  //   if (image == null) return;
  //
  //   final allowed = ['jpg', 'jpeg', 'png', 'webp'];
  //   final ext = image.path.split('.').last.toLowerCase();
  //
  //   if (!allowed.contains(ext)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text("Only JPG, JPEG, PNG, WEBP allowed"),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() {
  //     _otherImage = image;
  //   });
  // }

  Future<void> _handleOtherImage(XFile? image) async {
    if (image == null) return;

    final allowed = ['jpg', 'jpeg', 'png', 'webp'];
    final ext = image.path.split('.').last.toLowerCase();

    if (!allowed.contains(ext)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Only JPG, PNG, JPEG, WEBP allowed")),
      );
      return;
    }

    File file = File(image.path);

    // 🔥 Compress
    final compressed = await _compressImage(file);

    // fallback if compression fails
    final finalFile = compressed ?? file;

    final size = await finalFile.length();

    if (size > maxImageSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Image must be less than 2MB"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _otherImage = XFile(finalFile.path);
    });
  }

  Future<void> _pickImageOtherAllowance() async {
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
                  final image = await _otherImagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  _handleOtherImage(image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Select from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _otherImagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  _handleOtherImage(image);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDoc() async {
    debugPrint('[Reimbursement][Create] Opening document picker');
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png'
      ],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      // Assign to both docs for now, or split logic if needed
      setState(() {
        _dailyDoc = result.files.first;
        _otherDoc = result.files.first;
      });
      debugPrint(
        '[Reimbursement][Create] Document selected: ${result.files.first.path ?? result.files.first.name}',
      );
    }
  }

  // Future<void> _submitExpenseRequest() async {
  //   debugPrint('[Reimbursement][Create] Submit tapped');
  //   FocusScope.of(context).unfocus();
  //
  //   if (_selectedExpenseTypes.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Please select at least one expense type.'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   if (!(_formKey.currentState?.validate() ?? false)) {
  //     return;
  //   }
  //
  //   final String? token =
  //       Provider.of<UserProvider>(context, listen: false).token;
  //   debugPrint('[Reimbursement][Create] Token on submit: $token');
  //   if (token == null || token.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('User token not found. Please login again.'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //     return;
  //   }
  //
  //   setState(() {
  //     _isSubmitting = true;
  //   });
  //
  //   try {
  //     final uri = Uri.parse('${AppConfig.baseURL}$_createExpenseEndpoint');
  //     debugPrint('[Reimbursement][Create][API] POST $uri');
  //     // Example: Only submit daily allowance if selected
  //     if (_selectedExpenseTypes.contains('DAILY_ALLOWANCE')) {
  //       final request = http.MultipartRequest('POST', uri)
  //         ..headers['Authorization'] = 'Bearer $token'
  //         ..headers['x-app-type'] = 'oms'
  //         ..fields['date'] = DateFormat('yyyy-MM-dd').format(_selectedDate)
  //         ..fields['expenseType'] = 'DAILY_ALLOWANCE'
  //         ..fields['amount'] = _dailyAmountController.text.trim()
  //         ..fields['notes'] = _dailyNotesController.text.trim();
  //       debugPrint(
  //           '[Reimbursement][Create][API] Payload fields: ${request.fields}');
  //       if (_dailyImageFile != null) {
  //         request.files.add(
  //           await http.MultipartFile.fromPath('image', _dailyImageFile!.path),
  //         );
  //         debugPrint(
  //             '[Reimbursement][Create][API] Attached image: ${_dailyImageFile!.path}');
  //       }
  //       if (_dailyDoc?.path != null && _dailyDoc!.path!.isNotEmpty) {
  //         request.files.add(
  //           await http.MultipartFile.fromPath('doc', _dailyDoc!.path!),
  //         );
  //         debugPrint(
  //             '[Reimbursement][Create][API] Attached doc: ${_dailyDoc!.path!}');
  //       }
  //       final streamedResponse = await request.send();
  //       final String responseBody =
  //           await streamedResponse.stream.bytesToString();
  //       debugPrint(
  //           '[Reimbursement][Create][API] Response status: ${streamedResponse.statusCode}');
  //       debugPrint('[Reimbursement][Create][API] Response body: $responseBody');
  //       String message = streamedResponse.statusCode >= 200 &&
  //               streamedResponse.statusCode < 300
  //           ? 'Expense reimbursement submitted successfully'
  //           : 'Failed to submit expense reimbursement';
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(message),
  //           backgroundColor: streamedResponse.statusCode >= 200 &&
  //                   streamedResponse.statusCode < 300
  //               ? Colors.green
  //               : Colors.red,
  //         ),
  //       );
  //       if (streamedResponse.statusCode >= 200 &&
  //           streamedResponse.statusCode < 300) {
  //         Get.offAll(HomePage());
  //       }
  //     }
  //     // Repeat for OTHER_ALLOWANCE if needed
  //     if (_selectedExpenseTypes.contains('OTHER_ALLOWANCE')) {
  //       final request = http.MultipartRequest('POST', uri)
  //         ..headers['Authorization'] = 'Bearer $token'
  //         ..headers['x-app-type'] = 'oms'
  //         ..fields['date'] = DateFormat('yyyy-MM-dd').format(_selectedDate)
  //         ..fields['expenseType'] = 'OTHER_ALLOWANCE'
  //         ..fields['amount'] = _otherAmountController.text.trim()
  //         ..fields['notes'] = _otherNotesController.text.trim();
  //       debugPrint(
  //           '[Reimbursement][Create][API] Payload fields: ${request.fields}');
  //       if (_otherImage != null) {
  //         request.files.add(
  //           await http.MultipartFile.fromPath('image', _otherImage!.path),
  //         );
  //         debugPrint(
  //             '[Reimbursement][Create][API] Attached image: ${_otherImage!.path}');
  //       }
  //       if (_otherDoc?.path != null && _otherDoc!.path!.isNotEmpty) {
  //         request.files.add(
  //           await http.MultipartFile.fromPath('doc', _otherDoc!.path!),
  //         );
  //         debugPrint(
  //             '[Reimbursement][Create][API] Attached doc: ${_otherDoc!.path!}');
  //       }
  //       final streamedResponse = await request.send();
  //       final String responseBody =
  //           await streamedResponse.stream.bytesToString();
  //       debugPrint(
  //           '[Reimbursement][Create][API] Response status: ${streamedResponse.statusCode}');
  //       debugPrint('[Reimbursement][Create][API] Response body: $responseBody');
  //       String message = streamedResponse.statusCode >= 200 &&
  //               streamedResponse.statusCode < 300
  //           ? 'Expense reimbursement submitted successfully'
  //           : 'Failed to submit expense reimbursement';
  //       if (!mounted) return;
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(message),
  //           backgroundColor: streamedResponse.statusCode >= 200 &&
  //                   streamedResponse.statusCode < 300
  //               ? Colors.green
  //               : Colors.red,
  //         ),
  //       );
  //       if (streamedResponse.statusCode >= 200 &&
  //           streamedResponse.statusCode < 300) {
  //         Get.offAll(HomePage());
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('[Reimbursement][Create][API] Exception: $e');
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Something went wrong: $e'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _submitExpenseRequest() async {
    FocusScope.of(context).unfocus();

    if (_selectedExpenseTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one expense type')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = Provider.of<UserProvider>(context, listen: false).token;

    if (token == null || token.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse('${AppConfig.baseURL}$_createExpenseEndpoint');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['x-app-type'] = 'oms';

      int index = 1;

      // 🟢 DAILY ALLOWANCE
      if (_selectedExpenseTypes.contains('DAILY_ALLOWANCE')) {
        request.fields['date$index'] =
            DateFormat('yyyy-MM-dd').format(_selectedDate);
        request.fields['expenseType$index'] = 'DAILY_ALLOWANCE';
        request.fields['amount$index'] = _dailyAmountController.text.trim();
        request.fields['notes$index'] = _dailyNotesController.text.trim();

        if (_dailyImageFile != null) {
          final file = File(_dailyImageFile!.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
            final typeSplit = mimeType.split('/');

            request.files.add(
              http.MultipartFile.fromBytes(
                'img$index',
                bytes,
                filename: p.basename(file.path),
                contentType: http.MediaType(typeSplit[0], typeSplit[1]),
              ),
            );
            debugPrint(
                '📎 Attached img$index: ${p.basename(file.path)} ($mimeType)');
          }
        }

        if (_dailyDoc != null && _dailyDoc!.path != null) {
          final file = File(_dailyDoc!.path!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mimeType = lookupMimeType(file.path) ?? 'application/pdf';
            final typeSplit = mimeType.split('/');

            request.files.add(
              http.MultipartFile.fromBytes(
                'doc$index',
                bytes,
                filename: p.basename(file.path),
                contentType: http.MediaType(typeSplit[0], typeSplit[1]),
              ),
            );
            debugPrint(
                '📎 Attached doc$index: ${p.basename(file.path)} ($mimeType)');
          }
        }

        debugPrint('Added Daily Allowance (index $index)');
        log('Added Daily Allowance (index $index)');
        index++;
      }

      // 🔵 OTHER ALLOWANCE
      if (_selectedExpenseTypes.contains('OTHER_ALLOWANCE')) {
        request.fields['date$index'] =
            DateFormat('yyyy-MM-dd').format(_selectedDate);
        request.fields['expenseType$index'] = 'OTHER_ALLOWANCE';
        request.fields['amount$index'] = _otherAmountController.text.trim();
        request.fields['notes$index'] = _otherNotesController.text.trim();

        if (_otherImage != null) {
          final file = File(_otherImage!.path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
            final typeSplit = mimeType.split('/');

            request.files.add(
              http.MultipartFile.fromBytes(
                'img$index',
                bytes,
                filename: p.basename(file.path),
                contentType: http.MediaType(typeSplit[0], typeSplit[1]),
              ),
            );
            debugPrint(
                '📎 Attached img$index: ${p.basename(file.path)} ($mimeType)');
          }
        }

        if (_otherDoc != null && _otherDoc!.path != null) {
          final file = File(_otherDoc!.path!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mimeType = lookupMimeType(file.path) ?? 'application/pdf';
            final typeSplit = mimeType.split('/');

            request.files.add(
              http.MultipartFile.fromBytes(
                'doc$index',
                bytes,
                filename: p.basename(file.path),
                contentType: http.MediaType(typeSplit[0], typeSplit[1]),
              ),
            );
            debugPrint(
                '📎 Attached doc$index: ${p.basename(file.path)} ($mimeType)');
          }
        }

        debugPrint('Added Other Allowance (index $index)');
        log('Added Other Allowance (index $index)');
      }

      debugPrint("FIELDS: ${request.fields}");
      debugPrint(
          "FILES: ${request.files.map((e) => '${e.field}: ${e.filename} (${e.contentType})')}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE BODY: ${response.body}");

      final decoded = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decoded['message'] ?? 'Success'),
          backgroundColor:
              response.statusCode >= 200 && response.statusCode < 300
                  ? Colors.green
                  : Colors.red,
        ),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Get.offAll(() => BottomnavigationBarScreen());
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('Exception during submission: $e');
      log('Exception during submission: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Reimbursement][Create] Building screen');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Request',
        ),
        foregroundColor: Colors.white,
        // actions: [
        //   IconButton(
        //     onPressed: () {
        //       Get.to(() => GetExpenseView());
        //     },
        //     icon: Icon(
        //       Icons.visibility,
        //     ),
        //   ),
        // ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: ValueKey(_selectedDate.toIso8601String()),
                initialValue: DateFormat('yyyy-MM-dd').format(_selectedDate),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              // Expense type checkboxes

              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      value: _selectedExpenseTypes.contains('DAILY_ALLOWANCE'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Daily Allowance'),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedExpenseTypes.add('DAILY_ALLOWANCE');
                          } else {
                            _selectedExpenseTypes.remove('DAILY_ALLOWANCE');
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CheckboxListTile(
                      value: _selectedExpenseTypes.contains('OTHER_ALLOWANCE'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Other Allowance'),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedExpenseTypes.add('OTHER_ALLOWANCE');
                          } else {
                            _selectedExpenseTypes.remove('OTHER_ALLOWANCE');
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // if (_selectedExpenseTypes.isNotEmpty)
              //   Padding(
              //     padding: const EdgeInsets.only(bottom: 8.0),
              //     child: Wrap(
              //       spacing: 8,
              //       children: _selectedExpenseTypes
              //           .map((type) => Chip(label: Text(type)))
              //           .toList(),
              //     ),
              //   ),

              if (_selectedExpenseTypes.contains("DAILY_ALLOWANCE"))
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Daily Allowance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _dailyAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount(₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dailyNotesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Please enter notes';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                          'Image: ${_dailyImageFile?.name ?? 'No image selected'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImageDailyAllowance,
                              icon: const Icon(Icons.image),
                              label: const Text('Pick Image'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _dailyImageFile == null
                                ? null
                                : () => setState(() {
                                      _dailyImageFile = null;
                                    }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Doc: ${_dailyDoc?.name ?? 'No document selected'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDocDaily,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Pick Document'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _dailyDoc == null
                                ? null
                                : () => setState(() {
                                      _dailyDoc = null;
                                    }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_selectedExpenseTypes.contains("OTHER_ALLOWANCE"))
                Container(
                  margin: EdgeInsets.only(top: 16),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Other Allowance",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      TextFormField(
                        controller: _otherAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount(₹)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherNotesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Please enter notes';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                          'Image: ${_otherImage?.name ?? 'No image selected'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImageOtherAllowance,
                              icon: const Icon(Icons.image),
                              label: const Text('Pick Image'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _otherImage == null
                                ? null
                                : () => setState(() {
                                      _otherImage = null;
                                    }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Doc: ${_otherDoc?.name ?? 'No document selected'}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDocOther,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Pick Document'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _otherDoc == null
                                ? null
                                : () => setState(() {
                                      _otherDoc = null;
                                    }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitExpenseRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
