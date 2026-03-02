import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/views/narration/narration_model.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/common_dropdown.dart';
import 'package:arham_corporation/widgets/common_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_button.dart';
import '../loginpage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class NarrationController extends GetxController {
  var isLoading = false.obs;
  var isDisable = false.obs;

  var isBottomLoading = false.obs;
  var isDeleteLoading = false.obs;

  // Controllers
  Rx<TextEditingController> narrationCodeController =
      TextEditingController().obs;
  Rx<TextEditingController> narrationNameController =
      TextEditingController().obs;

  FocusNode narrationCodeFocus = FocusNode();
  FocusNode narrationNameFocus = FocusNode();

  Rx<NarrationModel> narrationList = NarrationModel().obs;
  RxList<Data> searchList = <Data>[].obs; // List to store all groups
  Rx<TextEditingController> searchNarrationController =
      TextEditingController().obs;
  FocusNode searchNarrationFocus = FocusNode();
  RxString searchQuery = ''.obs; // Holds the search query

  RxString errorMsg = ''.obs;
  RxString type = ''.obs;
  RxString narrationID = ''.obs;

  //late RxList<String> narrationTypeList = <String>[].obs; // Initialize
  late RxList<Map<String, String>> narrationTypeList =
      <Map<String, String>>[].obs;

  //RxString? selectedNarrationType = ''.obs;
  ValueNotifier<String?> selectedNarrationType = ValueNotifier<String?>('');

  var moduleNo = ''.obs;
  var readRight = false.obs;
  var writeRights = false.obs;
  var updateRights = false.obs;
  var deleteRights = false.obs;
  var printRights = false.obs;

  // Get screen width and height
  double screenWidth = MediaQuery.of(Get.context!).size.width;
  double screenHeight = MediaQuery.of(Get.context!).size.height;

  // Set the desired margins
  double marginBottom = 56.0;
  double marginRight = 20.0;

  // Set the floating action button's size
  double fabSize = 56.0; // Default size of a FloatingActionButton

  // Calculate dx and dy based on screen size and margins
  double dx = 0.0;
  double dy = 0.0;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    dx = screenWidth - fabSize - marginRight;
    dy = screenHeight - fabSize - marginBottom;

    moduleNo.value = Get.arguments['ModuleNo'] ?? '';
    readRight.value = Get.arguments['ReadRight'] ?? false;
    writeRights.value = Get.arguments['WriteRight'] ?? false;
    updateRights.value = Get.arguments['UpdateRight'] ?? false;
    deleteRights.value = Get.arguments['DeleteRight'] ?? false;
    printRights.value = Get.arguments['PrintRight'] ?? false;

    if (kDebugMode) {
      print("Narration Screen : Module No : ${moduleNo.value}");
      print("Narration Screen : Read Right : ${readRight.value}");
      print("Narration Screen : Write Right : ${writeRights.value}");
      print("Narration Screen : Update Right : ${updateRights.value}");
      print("Narration Screen : Delete Right : ${deleteRights.value}");
      print("Narration Screen : Print Right : ${printRights.value}");
    }

    //narrationTypeList.value = _getDropdownItems();

    narrationTypeList.value = <Map<String, String>>[
      {'value': 'OTHER_DESC', 'label': 'Free/Scheme'},
      {'value': 'FLD5', 'label': 'Item Remark'},
      {'value': 'NARRATION', 'label': 'Order Remark'},
    ];

    fetchNarration();
  }

  @override
  void dispose() {
    narrationCodeController.value.dispose();
    narrationNameController.value.dispose();
    super.dispose();
  }

  void addValidationWithAPI() {
    if (narrationNameController.value.text.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please enter narration name.');
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter narration name.');
    } else if (selectedNarrationType.value!.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please enter narration type.');
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter narration type.');
    } else {
      insertDepartment(
        narrationNameController.value.text,
        selectedNarrationType.value!,
      );
    }
  }

  void editValidationWithAPI(String narrationId) {
    if (narrationNameController.value.text.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please enter narration name.');
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter narration name.');
    } else if (selectedNarrationType.value!.isEmpty) {
      //Fluttertoast.showToast(msg: 'Please enter narration type.');
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter narration type.');
    } else {
      updateDepartment(
        narrationId,
        narrationNameController.value.text,
        selectedNarrationType.value!,
      );
    }
  }

  Future<void> insertDepartment(
    String narrationName,
    String narrationType,
  ) async {
    final url = Uri.parse('${AppConfig.baseURL}master-entry/narration');

    try {
      final UserProvider ub =
          Provider.of<UserProvider>(Get.context!, listen: false);

      Map<String, dynamic> payload = {
        'narrName': narrationName,
        'narrType': narrationType,
        "moduleNo": "109"
      };

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token!}",
          'Content-Type': 'application/json',
          'x-app-type': 'oms',
        },
        body: jsonEncode(payload),
      );

      print('URL : $url');
      print('Body : $payload');
      print('Token : "Bearer ${ub.token!}"');
      //print('Response $response');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.back();

        narrationCodeController.value.clear();
        narrationNameController.value.clear();
        selectedNarrationType.value = '';

        AppSnackBar.showGetXCustomSnackBar(
            message: 'Narration added successfully!',
            backgroundColor: Colors.green);

        fetchNarration();
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
                'Failed to add company: ${response.statusCode} - ${response.body}'),
          ),
        );
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text('An error occurred: ${e.toString()}')),
      );
    }
  }

  Future<void> updateDepartment(
    String narrId,
    String narrationName,
    String narrationType,
  ) async {
    final url = Uri.parse('${AppConfig.baseURL}master-entry/narration');

    try {
      final UserProvider ub =
          Provider.of<UserProvider>(Get.context!, listen: false);

      Map<String, dynamic> payload = {
        'narrId': narrId,
        'narrName': narrationName,
        'narrType': narrationType,
        "moduleNo": "109"
      };

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token!}",
          'Content-Type': 'application/json',
          'x-app-type': 'oms',
        },
        body: jsonEncode(payload),
      );

      print('URL $url');
      print('Body $payload');
      print('Response $response');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.back();

        narrationCodeController.value.clear();
        narrationNameController.value.clear();
        selectedNarrationType.value = '';

        AppSnackBar.showGetXCustomSnackBar(
            message: 'Narration Update successfully!',
            backgroundColor: Colors.green);

        fetchNarration();
      } else {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
                'Failed to add company: ${response.statusCode} - ${response.body}'),
          ),
        );
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text('An error occurred: ${e.toString()}')),
      );
    }
  }

  Future<void> fetchNarration() async {
    try {
      isLoading(true);

      final UserProvider ub =
          Provider.of<UserProvider>(Get.context!, listen: false);

      // Send HTTPS request using http package
      String url = '${AppConfig.baseURL}/master-entry/narration';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        // Parse the response body into the NarrationModel
        narrationList.value =
            NarrationModel.fromJson(json.decode(response.body));

        // Check if data exists and isn't empty
        if (narrationList.value.data != null &&
            narrationList.value.data!.isNotEmpty) {
          if (narrationList.value.message == 'Data fetch successfully') {
            // Store the original data in searchList for filtering
            searchList.value = narrationList.value.data!;
          } else {
            // Fluttertoast.showToast(
            //     msg: narrationList.value.message ?? 'Unknown error');
            AppSnackBar.showGetXCustomSnackBar(
                message: narrationList.value.message ?? 'Unknown error');
          }
        } else {
          AppSnackBar.showGetXCustomSnackBar(message: 'No data found.');

          //Fluttertoast.showToast(msg: 'No data found.');
        }
      } else {
        ub.userSignout(Get.context!).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      print(e);
      AppSnackBar.showGetXCustomSnackBar(
          message: "Error fetching narration: $e");
      //Fluttertoast.showToast(msg: "Error fetching narration: $e");
    } finally {
      isLoading(false);
    }
  }

  void addNarration(BuildContext context) {
    narrationID.value = "";
    type.value = "A";

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      // Allow the sheet to be scrollable
      backgroundColor: Colors.white,
      // Set background color to white
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
              left: 16.0,
              right: 16.0,
              top: 16.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CommonText(
                        padding: const EdgeInsets.only(top: 10),
                        text: 'Add Narration',
                        color: Colors.blue,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                      IconButton(
                        highlightColor: Colors.transparent,
                        icon:
                            const Icon(Icons.cancel_outlined, color: Colors.blue),
                        onPressed: () {
                          Get.back();
                          narrationCodeController.value.clear();
                          narrationNameController.value.clear();
                          selectedNarrationType.value = '';
                        },
                      ),
                    ],
                  ),
                  const Visibility(visible: true, child: SizedBox(height: 16)),
                  CommonAppInput(
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    textEditingController: narrationNameController.value,
                    hintText: "Narration name (Must start with A–Z or _)",
                    focusNode: narrationNameFocus,
                    labelStyle: const TextStyle(
                      color: Colors.black,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                    ),
                    inputFormatters: [
                      StartWithAlphabetOrUnderscoreFormatter(),
                    ],
                    labelText: "Narration name (Must start with A–Z or _)",
                  ),
                  const SizedBox(height: 16),
                  // CommonDropdown(
                  //   items: narrationTypeList,
                  //   initialValue:
                  //       narrationTypeList.contains(selectedNarrationType?.value)
                  //           ? selectedNarrationType?.value
                  //           : null, // Ensure the value is valid
                  //   hint: "Select Narration Type",
                  //   onChanged: (value) {
                  //     selectedNarrationType?.value = value;
                  //   },
                  // ),
                  Visibility(
                    visible: false,
                    child: CommonDropdown(
                      items: narrationTypeList
                          .map((e) => e['label'] ?? '')
                          .toList(), // Ensure non-null labels
                      initialValue: narrationTypeList.firstWhere(
                        (element) =>
                            element['value'] == selectedNarrationType.value,
                        orElse: () =>
                            {'label': ''}, // Default map to avoid null errors
                      )['label'],
                      hint: "Select Narration Type",
                      onChanged: (value) {
                        // Find the selected item's actual value
                        final selectedItem = narrationTypeList.firstWhere(
                          (element) => element['label'] == value,
                          orElse: () =>
                              {'value': ''}, // Default map to avoid null errors
                        );

                        if (selectedItem['value']!.isNotEmpty) {
                          selectedNarrationType.value = selectedItem['value']!;
                        }
                      },
                    ),
                  ),

                  ValueListenableBuilder(
                    valueListenable: selectedNarrationType,
                    builder: (context, selectedValue, _) {
                      return CommonDropdown(
                        items: narrationTypeList
                            .map((e) => e['label'] ?? '')
                            .toList(),
                        initialValue: narrationTypeList.firstWhere(
                              (element) => element['value'] == selectedValue,
                              orElse: () => {'label': ''},
                            )['label'] ??
                            '',
                        hint: "Select Narration Type",
                        onChanged: (value) {
                          final selectedItem = narrationTypeList.firstWhere(
                            (element) => element['label'] == value,
                            orElse: () => {'value': ''},
                          );
                          if (selectedItem['value']!.isNotEmpty) {
                            selectedNarrationType.value = selectedItem['value']!;
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  isBottomLoading.value
                      ? CircularProgressIndicator() // Loader
                      : CommonButton(
                          buttonText: 'Add',
                          onPressed: () {
                            addValidationWithAPI();
                          },
                          isLoading: isLoading.value,
                          isDisable: isDisable.value,
                        ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  List<String> _getDropdownItems() {
    return [
      'OTHER_DESC',
      'FLD5',
      'NARRATION',
    ];
  }

  void editDepartment(BuildContext context, int index) {
    narrationID.value = narrationList.value.data![index].nARRID.toString();
    type.value = "U";

    narrationCodeController.value.text =
        narrationList.value.data![index].nARRID.toString();
    narrationNameController.value.text =
        narrationList.value.data![index].nARRNAME ?? '';
    selectedNarrationType.value =
        narrationList.value.data![index].nARRTYPE ?? '';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      // Allow the sheet to be scrollable
      backgroundColor: Colors.white,
      // Set background color to white
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
              left: 16.0,
              right: 16.0,
              top: 16.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CommonText(
                        padding: const EdgeInsets.only(top: 10),
                        text: 'Edit Narration',
                        color: Colors.blue,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                      IconButton(
                        highlightColor: Colors.transparent,
                        icon:
                            const Icon(Icons.cancel_outlined, color: Colors.blue),
                        onPressed: () {
                          Get.back();
                          narrationCodeController.value.clear();
                          narrationNameController.value.clear();
                          selectedNarrationType.value = '';
                        },
                      ),
                    ],
                  ),
                  const Visibility(visible: true, child: SizedBox(height: 16)),
                  CommonAppInput(
                    maxLength: 40,
                    textInputAction: TextInputAction.done,
                    textEditingController: narrationNameController.value,
                    hintText: "Narration name (Must start with A–Z or _)",
                    focusNode: narrationNameFocus,
                    labelStyle: const TextStyle(
                      color: Colors.black,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                    ),
                    inputFormatters: [
                      StartWithAlphabetOrUnderscoreFormatter(),
                    ],
                    labelText: "Narration name (Must start with A–Z or _)",
                  ),
                  const SizedBox(height: 16),
                  // CommonDropdown(
                  //   items: narrationTypeList,
                  //   initialValue:
                  //       narrationTypeList.contains(selectedNarrationType?.value)
                  //           ? selectedNarrationType?.value
                  //           : null, // Ensure the value is valid
                  //   hint: "Select Narration Type",
                  //   onChanged: (value) {
                  //     selectedNarrationType?.value = value;
                  //   },
                  // ),
                  Visibility(
                    visible: false,
                    child: CommonDropdown(
                      items: narrationTypeList
                          .map((e) => e['label'] ?? '')
                          .toList(), // Ensure non-null labels
                      initialValue: narrationTypeList.firstWhere(
                        (element) =>
                            element['value'] == selectedNarrationType.value,
                        orElse: () =>
                            {'label': ''}, // Default map to avoid null errors
                      )['label'],
                      hint: "Select Narration Type",
                      onChanged: (value) {
                        // Find the selected item's actual value
                        final selectedItem = narrationTypeList.firstWhere(
                          (element) => element['label'] == value,
                          orElse: () =>
                              {'value': ''}, // Default map to avoid null errors
                        );

                        if (selectedItem['value']!.isNotEmpty) {
                          selectedNarrationType.value = selectedItem['value']!;
                        }
                      },
                    ),
                  ),

                  ValueListenableBuilder(
                    valueListenable: selectedNarrationType,
                    builder: (context, selectedValue, _) {
                      return CommonDropdown(
                        items: narrationTypeList
                            .map((e) => e['label'] ?? '')
                            .toList(),
                        initialValue: narrationTypeList.firstWhere(
                              (element) => element['value'] == selectedValue,
                              orElse: () => {'label': ''},
                            )['label'] ??
                            '',
                        hint: "Select Narration Type",
                        onChanged: (value) {
                          final selectedItem = narrationTypeList.firstWhere(
                            (element) => element['label'] == value,
                            orElse: () => {'value': ''},
                          );
                          if (selectedItem['value']!.isNotEmpty) {
                            selectedNarrationType.value = selectedItem['value']!;
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  CommonButton(
                    buttonText: 'Update',
                    onPressed: () {
                      editValidationWithAPI(narrationID.value);
                    },
                    isLoading: isLoading.value,
                    isDisable: isDisable.value,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> deleteNarration(
      BuildContext context, String narrId, String narrName) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      String url = '${AppConfig.baseURL}/master-entry/narration/$narrId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        Navigator.pop(context);
        AppSnackBar.showGetXCustomSnackBar(
            message: "Narration deleted successfully : ${narrName}",
            backgroundColor: Colors.green);
        //Fluttertoast.showToast(msg: "Narration deleted successfully : ${narrName}");
        fetchNarration();
      } else {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'An error occurred.';
        AppSnackBar.showGetXCustomSnackBar(message: message);
        //Fluttertoast.showToast(msg: message);
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong: $e");
      //Fluttertoast.showToast(msg: "Something went wrong: $e");
    }
  }
}
