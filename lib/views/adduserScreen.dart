import 'dart:convert';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/person_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/personModal.dart';
import '../product/widget/app_snack_bar.dart';
import '../providers/user_provider.dart';

class AddUserScreen extends StatefulWidget {
  final int screenId;
  final DatumPerson? data;

  const AddUserScreen({super.key, required this.screenId, this.data});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  TextEditingController userCdClt = TextEditingController();
  TextEditingController passwordClt = TextEditingController();
  TextEditingController userNameClt = TextEditingController();
  TextEditingController mobileNumberClt = TextEditingController();

  FocusNode userCdFocusNode = FocusNode();
  FocusNode passwordFocusNode = FocusNode();
  FocusNode userNameFocusNode = FocusNode();
  FocusNode mobileNumberFocusNode = FocusNode();

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
  bool isLoading = true; // Indicates loading state

  getModules() {
    Services().getModules(context).then((value) {
      setState(() {
        modules.addAll(value?.data ?? []);
        if (widget.screenId != 0) {
          filterModules = modules.where((m) {
            if (m.aPPTYPE.toString().trim().toUpperCase() == "OMS") {
              // Only allow OMSReport modules with matching role
              return m.moduleType == "OMSReport" &&
                  m.role.contains(selectRole!.id);
            } else {
              // For Master & Transaction → always include
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

  @override
  void initState() {
    super.initState();
    firmAPI();
    getModules();
    // Initialize focus nodes
    userCdFocusNode.addListener(() {
      if (userCdFocusNode.hasFocus) {
        // Clear the text field when focused
        userCdClt.clear();
      }
    });
    passwordFocusNode.addListener(() {
      if (passwordFocusNode.hasFocus) {
        // Clear the text field when focused
        passwordClt.clear();
      }
    });
    userNameFocusNode.addListener(() {
      if (userNameFocusNode.hasFocus) {
        // Clear the text field when focused
        userNameClt.clear();
      }
    });
    mobileNumberFocusNode.addListener(() {
      if (mobileNumberFocusNode.hasFocus) {
        // Clear the text field when focused
        mobileNumberClt.clear();
      }
    });

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
    super.dispose();
  }

  setData() {
    setState(() {
      userCdClt.text = widget.data!.userCd;
      userNameClt.text = widget.data!.userName;
      //passwordClt.text = widget.data!.userPwd;
      activeuser = !widget.data!.blacklist;
      mobileNumberClt.text = widget.data!.mobileno ?? "";
      selectRole =
          role.firstWhere((element) => element.id == widget.data!.userType);
      //selectModules = widget.data!.moduleNos;

      //TODO : OLD
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

      //TODO : New With Rights
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
                  if (widget.screenId == 0)
                    UserTextField(
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
                    clt: passwordClt,
                    hint: "Password",
                    maxLength: 10,
                  ),
                  SizedBox(
                    height: 5.h,
                  ),
                  UserTextField(
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
                                return m.moduleType == "OMSReport" &&
                                    m.role.contains(selectRole!.id);
                              } else {
                                // For Master & Transaction → always include
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
                      else
                        Column(
                          children: [
                            SizedBox(
                              height: 10,
                            ),
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
                                )
                              ],
                            ),
                            Divider(),
                            ListView.builder(
                                itemCount: filterModules.length,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemBuilder: (context, i) {
                                  // bool isReportModule = filterModules[i]
                                  //     .moduleName
                                  //     .contains('Report');

                                  bool isReportModule =
                                      filterModules[i].moduleType ==
                                          'OMSReport';
                                  //.contains('OMSReport');

                                  return Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              "${filterModules[i].moduleName}",
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                // Show "All" checkbox if module name doesn't contain 'Report', else hide with Visibility
                                                Expanded(
                                                  flex: 1,
                                                  child: Visibility(
                                                    visible: !isReportModule,
                                                    // Show when not a Report module
                                                    child: _buildRightCheckbox(
                                                      filterModules[i].moduleNo,
                                                      "All",
                                                      "readRight",
                                                      "writeRight",
                                                      "updateRight",
                                                      "deleteRight",
                                                      "printRight",
                                                    ),
                                                  ),
                                                ),

                                                // "View" checkbox is always shown
                                                Expanded(
                                                  flex: 1,
                                                  child: _buildRightCheckbox(
                                                    filterModules[i].moduleNo,
                                                    "View",
                                                    "readRight",
                                                  ),
                                                ),

                                                // Show "Add" checkbox if module name doesn't contain 'Report', else hide with Visibility
                                                Expanded(
                                                  flex: 1,
                                                  child: Visibility(
                                                    visible: !isReportModule,
                                                    child: _buildRightCheckbox(
                                                      filterModules[i].moduleNo,
                                                      "Add",
                                                      "writeRight",
                                                    ),
                                                  ),
                                                ),

                                                // Show "Edit" checkbox if module name doesn't contain 'Report', else hide with Visibility
                                                Expanded(
                                                  flex: 1,
                                                  child: Visibility(
                                                    visible: !isReportModule,
                                                    child: _buildRightCheckbox(
                                                      filterModules[i].moduleNo,
                                                      "Edit",
                                                      "updateRight",
                                                    ),
                                                  ),
                                                ),

                                                // Show "Delete" checkbox if module name doesn't contain 'Report', else hide with Visibility
                                                Expanded(
                                                  flex: 1,
                                                  child: Visibility(
                                                    visible: !isReportModule,
                                                    child: _buildRightCheckbox(
                                                      filterModules[i].moduleNo,
                                                      "Delete",
                                                      "deleteRight",
                                                    ),
                                                  ),
                                                ),

                                                // "Print" checkbox is always shown
                                                Expanded(
                                                  flex: 1,
                                                  child: _buildRightCheckbox(
                                                    filterModules[i].moduleNo,
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
                                }),
                          ],
                        ),
                      // SizedBox(
                      //   height: 10.h,
                      // ),
                      // ListView.builder(
                      //   itemCount: filterModules.length,
                      //   shrinkWrap: true,
                      //   physics: NeverScrollableScrollPhysics(),
                      //   itemBuilder: (context, i) {
                      //     return Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         Text(
                      //           "${filterModules[i].moduleName}", // Module Name
                      //           style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                      //         ),
                      //         SingleChildScrollView(
                      //           scrollDirection: Axis.horizontal,
                      //           child: Row(
                      //             mainAxisAlignment: MainAxisAlignment.start,
                      //             children: [
                      //               // All checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "All",
                      //                   "readRight",
                      //                   "writeRight",
                      //                   "updateRight",
                      //                   "deleteRight",
                      //                   "printRight"),
                      //               // View checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "View",
                      //                   "readRight"),
                      //               // Add checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "Add",
                      //                   "writeRight"),
                      //               // Edit checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "Edit",
                      //                   "updateRight"),
                      //               // Delete checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "Delete",
                      //                   "deleteRight"),
                      //               // Print checkbox
                      //               _buildRightCheckbox(
                      //                   filterModules[i].moduleNo,
                      //                   "Print",
                      //                   "printRight"),
                      //             ],
                      //           ),
                      //         ),
                      //       ],
                      //     );
                      //   },
                      // ),
                    ],
                  ),
                  SizedBox(
                    height: 15.h,
                  ),
                  GestureDetector(
                    onTap: () {
                      if (userNameClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user name");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user name");
                      } else if (userCdClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user code");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user code");
                      } else if (passwordClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user password");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user password");
                      } else if (mobileNumberClt.text.isEmpty) {
                        //Fluttertoast.showToast(msg: "Please enter user phone no");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user phone no");
                      } else if (mobileNumberClt.text.isNotEmpty &&
                          mobileNumberClt.text.length != 10) {
                        //Fluttertoast.showToast(msg: "Please enter user 10 digit phone no");
                        AppSnackBar.showGetXCustomSnackBar(
                            message: "Please enter user 10 digit phone no");
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
                                  selectedFirmIds)
                              .then((value) {
                            person.changeLoading(false);
                            if (value == true) {
                              Get.back(result: 1);
                            }
                          });
                        } else {
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
                                  selectedFirmIds)
                              .then((value) {
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
      children: [
        Expanded(
          child: Checkbox(
            value: _isRightChecked(moduleNo, label, rightField, rightField2,
                rightField3, rightField4, rightField5),
            onChanged: (value) {
              setState(() {
                if (label == "All") {
                  // When 'All' checkbox is clicked, set all rights tol/p[o the same value
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
                  // When any specific checkbox ise clicked, just update that right
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
          ),
        ),
        Visibility(visible: false, child: Text(label)),
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
    this.maxLength,
    this.inputFormatters, // <--- added
  });

  final TextEditingController clt;
  final String hint;
  final TextInputType? type;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters; // <--- added

  @override
  _UserTextFieldState createState() => _UserTextFieldState();
}

class _UserTextFieldState extends State<UserTextField> {
  int currentLength = 0;

  @override
  void initState() {
    super.initState();

    currentLength = widget.clt.text.length;

    widget.clt.addListener(() {
      setState(() {
        currentLength = widget.clt.text.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 5.h),
        TextField(
          controller: widget.clt,
          keyboardType: widget.type,

          /// Use ONLY formatters passed by constructor
          inputFormatters: [
            if (widget.maxLength != null)
              LengthLimitingTextInputFormatter(widget.maxLength),

            // If user passed custom formatters → add them
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
