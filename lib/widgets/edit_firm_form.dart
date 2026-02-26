import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/widgets/common_app_input.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';

import '../models/firm_model.dart';
import 'package:http/http.dart' as http;

class EditFirmForm extends StatefulWidget {
  final FirmModel initialCompany;
  final void Function(FirmModel) onSubmit;

  EditFirmForm({
    required this.initialCompany,
    required this.onSubmit,
  });

  @override
  _EditFirmFormState createState() => _EditFirmFormState();
}

class _EditFirmFormState extends State<EditFirmForm>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late String companyName;
  late String address1;
  late String address2;
  late String address3;
  late String address4;
  late String address5; // New field
  late String city;
  late String state;
  late String stateCode;
  late String zone;
  late String mobile1;
  late String mobile2;
  late String personName;
  late String emailId;
  late String upi;
  late String gstNo;
  late String gstType; // GST Type as a String
  late String panNo;
  late String fssaiNo;
  late String registrationNo1; // New field for Registration No 1
  late String registrationNo2; // New field for Registration No 2
  late String tcsWithPan; // Changed to String type
  late String tcsWithoutPan; // Changed to String type
  late String tcsAuto; // Remains a String
  late double tcsAbove;
  late DateTime createdAt; // New field for creation timestamp
  late String footer1;
  late String footer2;
  late String footer3;
  late String footer4;
  late String footer5;
  late String pinCode; // New field for Pin Code
  // FocusNodes for each field
  final FocusNode companyNameFocusNode = FocusNode();
  final FocusNode personNameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode mobile1FocusNode = FocusNode();
  final FocusNode mobile2FocusNode = FocusNode();
  final FocusNode upiFocusNode = FocusNode();
  final FocusNode address1FocusNode = FocusNode();
  final FocusNode address2FocusNode = FocusNode();
  final FocusNode address3FocusNode = FocusNode();
  final FocusNode address4FocusNode = FocusNode();
  final FocusNode address5FocusNode = FocusNode();
  final FocusNode cityFocusNode = FocusNode();
  final FocusNode stateFocusNode = FocusNode();
  final FocusNode stateCodeFocusNode = FocusNode();
  final FocusNode zoneFocusNode = FocusNode();
  final FocusNode gstNoFocusNode = FocusNode();
  final FocusNode gstTypeFocusNode = FocusNode();
  final FocusNode panNoFocusNode = FocusNode();
  final FocusNode fssaiNoFocusNode = FocusNode();
  final FocusNode registrationNo1FocusNode = FocusNode();
  final FocusNode registrationNo2FocusNode = FocusNode();
  final FocusNode tcsWithPanFocusNode = FocusNode();
  final FocusNode tcsWithoutPanFocusNode = FocusNode();
  final FocusNode tcsAboveFocusNode = FocusNode();
  final FocusNode footer1FocusNode = FocusNode();
  final FocusNode footer2FocusNode = FocusNode();
  final FocusNode footer3FocusNode = FocusNode();
  final FocusNode footer4FocusNode = FocusNode();
  final FocusNode footer5FocusNode = FocusNode();
  final FocusNode pinCodeFocusNode = FocusNode();

  // List of GST Types
  final List<String> gstTypes = ['Regular', 'Composition', 'Exempted', 'None'];

  TextEditingController gstNoController = TextEditingController();
  final TextEditingController subGroupController = TextEditingController();
  final FocusNode subGroupFocus = FocusNode();
  List<Map<String, dynamic>> stateList = [];
  String? selectedStateCode; // Stores the selected sync ID
  String? selectedStateName; // Stores the selected firm name
  bool isLoading = true;

  final TextEditingController searchPartyClt = TextEditingController();
  FocusNode _focusNode = FocusNode();
  final List _tempParty = [];

// Function to open party selection menu
// The function to show the state selection modal
  void showPartySelectionMenu(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, StateSetter setStatee) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: Container(
                height: 450,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0, bottom: 14.0, top: 20.0),
                      child: Text(
                        "Select State:",
                        style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8),
                      ),
                    ),
                    // Search Field
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CupertinoSearchTextField(
                        controller: searchPartyClt,
                        focusNode: _focusNode,
                        onChanged: (value) {
                          setStatee(() {
                            _tempParty.clear();
                            // Filter party list based on search input
                            _tempParty.addAll(
                              stateList.where((state) {
                                final stateName =
                                    state["stateName"].toLowerCase();
                                final stateCd = state["stateCd"].toLowerCase();
                                return stateName
                                        .contains(value.toLowerCase()) ||
                                    stateCd.contains(value.toLowerCase());
                              }).toList(),
                            );
                          });
                        },
                      ),
                    ),
                    // List of states
                    Expanded(
                      child: isLoading
                          ? Center(
                              child:
                                  CircularProgressIndicator()) // Show loading if fetching
                          : stateList.isEmpty
                              ? Center(
                                  child: Text(
                                      "No List")) // Show if no states in API
                              : _tempParty.isEmpty &&
                                      searchPartyClt.text.isNotEmpty
                                  ? Center(child: Text("No Search State Found"))
                                  : ListView.builder(
                                      itemCount: _tempParty.isNotEmpty
                                          ? _tempParty.length
                                          : stateList.length,
                                      // Show filtered list or full list
                                      itemBuilder: (context, index) {
                                        var selectedState =
                                            _tempParty.isNotEmpty
                                                ? _tempParty[index]
                                                : stateList[index];
                                        return ListTile(
                                          onTap: () {
                                            setStatee(() {
                                              selectedStateName =
                                                  selectedState['stateName'];
                                              selectedStateCode =
                                                  selectedState['stateCd'];

                                              state = selectedStateName!;
                                              stateCode = selectedStateCode!;

                                              print(selectedStateName);
                                              print(selectedStateCode);
                                            });

                                            setState(() {});

                                            Navigator.pop(
                                                context); // Close the bottom sheet
                                          },
                                          leading: Text("${index + 1}"),
                                          title: Text(
                                            "(${selectedState['stateCd']}) ${selectedState['stateName']}",
                                            style: TextStyle(
                                                fontSize: 15.0,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          dense: true,
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _initializeFields();

    fetchData();

    // Listener for GST Number to auto-fill PAN
    //gstNo = widget.initialCompany.firmGstNo; // Initialize GST Number
  }

  Future<void> fetchData() async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    final url =
        Uri.parse(AppConfig.baseURL + 'states'); // Replace with your API URL

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> firms = data['data'];

        // Parse each entry to a map with firm name and sync ID
        setState(() {
          stateList = firms.map((item) {
            return {
              "stateName":
                  item['state_name']?.replaceAll(RegExp(r'[\r\n]'), '') ??
                      'Unnamed Firm',
              "stateCd": item['state_cd'],
            };
          }).toList();

          // Set default firm selection if list is not empty
          // if (firmList.isNotEmpty) {
          //   selectedSyncId = firmList[0]['stateCd'];
          //   selectedFirmName = firmList[0]['stateName'];
          // }

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    companyNameFocusNode.dispose();
    personNameFocusNode.dispose();
    emailFocusNode.dispose();
    mobile1FocusNode.dispose();
    mobile2FocusNode.dispose();
    upiFocusNode.dispose();
    address1FocusNode.dispose();
    address2FocusNode.dispose();
    address3FocusNode.dispose();
    address4FocusNode.dispose();
    address5FocusNode.dispose();
    cityFocusNode.dispose();
    stateFocusNode.dispose();
    stateCodeFocusNode.dispose();
    zoneFocusNode.dispose();
    gstNoFocusNode.dispose();
    gstTypeFocusNode.dispose();
    panNoFocusNode.dispose();
    fssaiNoFocusNode.dispose();
    registrationNo1FocusNode.dispose();
    registrationNo2FocusNode.dispose();
    tcsWithPanFocusNode.dispose();
    tcsWithoutPanFocusNode.dispose();
    tcsAboveFocusNode.dispose();
    footer1FocusNode.dispose();
    footer2FocusNode.dispose();
    footer3FocusNode.dispose();
    footer4FocusNode.dispose();
    footer5FocusNode.dispose();
    pinCodeFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    companyName = widget.initialCompany.firmName; // Updated to firmName
    address1 = widget.initialCompany.address1;
    address2 = widget.initialCompany.address2;
    address3 = widget.initialCompany.address3;
    address4 = widget.initialCompany.address4;
    address5 = widget.initialCompany.address5; // Initialize new field
    city = widget.initialCompany.firmCity; // Updated to firmCity
    state = widget.initialCompany.firmState; // Updated to firmState
    if (state.isNotEmpty) {
      selectedStateName = state;
      subGroupController.text = state;
    }
    stateCode = widget.initialCompany.firmStateCode;
    if (stateCode.isNotEmpty) {
      selectedStateCode = stateCode;
    }

    zone = widget.initialCompany.firmZone; // Updated to firmZone
    mobile1 = widget.initialCompany.firmMobile1; // Updated to firmMobile1
    mobile2 = widget.initialCompany.firmMobile2; // Updated to firmMobile2
    personName =
        widget.initialCompany.firmPersonName; // Updated to firmPersonName
    emailId = widget.initialCompany.firmEmailId; // Updated to firmEmailId
    upi = widget.initialCompany.firmUpi; // Updated to firmUpi
    gstNo = widget.initialCompany.firmGstNo; // Updated to firmGstNo
    gstType = widget.initialCompany.firmGstType.trim();
    panNo = widget.initialCompany.firmPanNo; // Updated to firmPanNo
    fssaiNo = widget.initialCompany.firmFssaiNo; // Updated to firmFssaiNo
    registrationNo1 = widget.initialCompany.firmRegistrationNo1; // Updated
    registrationNo2 = widget.initialCompany.firmRegistrationNo2; // Updated
    tcsWithPan =
        widget.initialCompany.tcsWithPan.toString(); // Changed to String
    tcsWithoutPan =
        widget.initialCompany.tcsWithoutPan.toString(); // Changed to String
    tcsAuto = widget.initialCompany.tcsAuto; // Remains a String
    tcsAbove = widget.initialCompany.tcsAbove;
    createdAt = widget.initialCompany.createdAt; // Initialize timestamp
    footer1 = widget.initialCompany.footer1;
    footer2 = widget.initialCompany.footer2;
    footer3 = widget.initialCompany.footer3;
    footer4 = widget.initialCompany.footer4;
    footer5 = widget.initialCompany.footer5;

    pinCode = widget.initialCompany.pinCode; // Initialize Pin Code
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final updatedCompany = FirmModel(
        firmName: companyName,
        address1: address1,
        address2: address2,
        address3: address3,
        address4: address4,
        address5: address5,
        // Include new field
        firmCity: city,
        firmState: state,
        firmStateCode: stateCode,
        firmZone: zone,
        firmMobile1: mobile1,
        firmMobile2: mobile2,
        firmPersonName: personName,
        firmEmailId: emailId,
        firmUpi: upi,
        firmGstNo: gstNo,
        firmGstType: gstType,
        // GST Type as a String
        firmPanNo: panNo,
        firmFssaiNo: fssaiNo,
        firmRegistrationNo1: registrationNo1,
        // Updated
        firmRegistrationNo2: registrationNo2,
        // Updated
        tcsWithPan: double.tryParse(tcsWithPan) ?? 0.00,
        // Convert back to double
        tcsWithoutPan: double.tryParse(tcsWithoutPan) ?? 0.00,
        // Convert back to double
        tcsAuto: tcsAuto,
        // Remains a String
        tcsAbove: tcsAbove,
        createdAt: createdAt,
        // Include timestamp
        footer1: footer1,
        footer2: footer2,
        footer3: footer3,
        footer4: footer4,
        footer5: footer5,
        pinCode: pinCode, // Include Pin Code
      );

      widget.onSubmit(updatedCompany);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    }
    final pattern =
        r'''(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])''';
    final regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty || value.length != 10) {
      return 'Please enter a valid phone number (10 digits)';
    }
    return null;
  }

  String? _validatePhone1(String? value) {
    if (value!.isNotEmpty && value.length != 10) {
      return 'Please enter a valid phone number (10 digits)';
    }
    return null; // valid
  }

  // ignore: unused_element
  String? _validateGST1(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length != 15) {
        return 'Please enter a valid GST number (15 digits)';
      }
    }
    return null;
  }

  String? _validateGST(String? gstType, String? gstNo) {
    if (gstType == null || gstType.isEmpty) {
      return 'Please select a GST type';
    }
    if (gstType != 'Exempted' && gstType != 'None') {
      if (gstNo == null || gstNo.isEmpty) {
        return 'GST No is required for the selected GST Type';
      }
      if (gstNo.length != 15) {
        return 'Please enter a valid GST number (15 digits)';
      }
    }
    return null;
  }

  String? _validatePAN(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length != 10) {
        return 'Please enter a valid PAN number (10 digits)';
      }
    }
    return null;
  }

  Widget _buildTextField(
    String label,
    String initialValue,
    Function(String) onChanged, {
    String? Function(String?)? validator,
    int? length,
    List<TextInputFormatter>? inputFormatters,
    TextEditingController? controller,
    TextInputAction? textInputAction,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    bool enabled =
        true, // Default is true, meaning the text field is enabled by default
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: TextFormField(
        enabled: enabled,
        // Use the enabled parameter to control the TextField's state
        initialValue: initialValue,
        controller: controller,
        textInputAction: textInputAction ?? TextInputAction.next,
        // Use the passed value or default to 'next'
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF8ac2e0), width: 2.0),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
        maxLength: length,
        keyboardType: keyboardType,
        // Set keyboard type
        inputFormatters: inputFormatters,
        // Use the passed inputFormatters
        onFieldSubmitted: (value) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDropdownField1(
    String label,
    String? initialValue,
    Function(String?) onChanged,
    List<String> options,
  ) {
    // Ensure initialValue is valid, otherwise set to null
    String? dropdownValue =
        options.contains(initialValue) ? initialValue : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: DropdownButtonFormField<String>(
        initialValue: dropdownValue,
        // No default selection if null
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF2c9ed9), width: 2.0),
          ),
        ),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select an option' : null,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String initialValue,
    Function(String?) onChanged,
    List<String> options,
  ) {
    // Check if the initial value exists in the options
    String? dropdownValue;
    if (options.contains(initialValue)) {
      dropdownValue = initialValue; // Set to initialValue if it's valid
    } else {
      dropdownValue =
          options.isNotEmpty ? options[0] : null; // Default to first option
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: DropdownButtonFormField<String>(
        initialValue: dropdownValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0XFF2c9ed9), width: 2.0),
          ),
        ),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select an option' : null,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8), // Leave space for button
                child: Column(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Company Details section
                          Column(
                            children: [
                              _buildTextField('Company Name', companyName,
                                  (value) => companyName = value,
                                  validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a company name';
                                }
                                return null;
                              },
                                  focusNode: companyNameFocusNode,
                                  nextFocusNode: personNameFocusNode,
                                  inputFormatters: [
                                    StartWithAlphabetOrUnderscoreFormatter()
                                  ]),
                              _buildTextField('Person Name', personName,
                                  (value) => personName = value,
                                  validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a person name';
                                }
                                return null;
                              },
                                  focusNode: personNameFocusNode,
                                  nextFocusNode: emailFocusNode,
                                  inputFormatters: [
                                    StartWithAlphabetOrUnderscoreFormatter()
                                  ]),
                              _buildTextField(
                                'Email ID',
                                emailId,
                                (value) => emailId = value,
                                validator: _validateEmail,
                                focusNode: emailFocusNode,
                                nextFocusNode: mobile1FocusNode,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      'Contact',
                                      mobile1,
                                      (value) => mobile1 = value,
                                      keyboardType: TextInputType.number,
                                      //length: 10,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(10),
                                        FilteringTextInputFormatter.digitsOnly,
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[6-9][0-9]{0,9}$')),
                                      ],
                                      validator: _validatePhone,
                                      focusNode: mobile1FocusNode,
                                      nextFocusNode: mobile2FocusNode,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: _buildTextField(
                                      'Alternate Contact',
                                      mobile2,
                                      (value) => mobile2 = value,
                                      keyboardType: TextInputType.number,
                                      //length: 10,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(10),
                                        FilteringTextInputFormatter.digitsOnly,
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^[6-9][0-9]{0,9}$')),
                                      ],
                                      validator: _validatePhone1,
                                      focusNode: mobile2FocusNode,
                                      nextFocusNode: upiFocusNode,
                                    ),
                                  ),
                                ],
                              ),
                              _buildTextField(
                                'UPI ID',
                                upi,
                                (value) => upi = value,
                                focusNode: upiFocusNode,
                                textInputAction: TextInputAction.next,
                                nextFocusNode: address1FocusNode
                              ),
                            ],
                          ),
                          TabBar(
                            controller: _tabController,
                            tabs: [
                              Tab(text: "Address"),
                              Tab(text: "GST Details"),
                            ],
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorColor: Color(0XFF2c9ed9),
                            labelColor: Color(0XFF2c9ed9),
                            unselectedLabelColor: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Container(
                            height: MediaQuery.sizeOf(context).height,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Address section
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTextField('Address 1', address1,
                                        (value) => address1 = value,
                                        focusNode: address1FocusNode,
                                        nextFocusNode: address2FocusNode),
                                    _buildTextField('Address 2', address2,
                                        (value) => address2 = value,
                                        focusNode: address2FocusNode,
                                        nextFocusNode: address3FocusNode),
                                    _buildTextField('Address 3', address3,
                                        (value) => address3 = value,
                                        focusNode: address3FocusNode,
                                        nextFocusNode: address4FocusNode),
                                    _buildTextField(
                                      'Address 4',
                                      address4,
                                      (value) => address4 = value,
                                      focusNode: address4FocusNode,
                                      nextFocusNode: address5FocusNode,
                                    ),
                                    _buildTextField(
                                      'Address 5',
                                      address5,
                                      (value) => address5 = value,
                                      focusNode: address5FocusNode,
                                      nextFocusNode: cityFocusNode,
                                    ),
                                    _buildTextField(
                                      'City',
                                      city,
                                      (value) => city = value,
                                      focusNode: cityFocusNode,
                                      nextFocusNode: zoneFocusNode,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Visibility(
                                        visible: false,
                                        child: isLoading
                                            ? CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 2.0,
                                              )
                                            : TypeAheadField<String>(
                                                suggestionsCallback:
                                                    (pattern) async {
                                                  // Filter the list based on pattern
                                                  return stateList
                                                      .where((item) => item[
                                                              'stateName']
                                                          .toString()
                                                          .toLowerCase()
                                                          .contains(pattern
                                                              .toLowerCase()))
                                                      .map((item) =>
                                                          item['stateName']
                                                              .toString())
                                                      .toList();
                                                },
                                                itemBuilder: (context,
                                                    String suggestion) {
                                                  return ListTile(
                                                    visualDensity:
                                                        VisualDensity(
                                                            horizontal: -4,
                                                            vertical: -4),
                                                    title: Text(
                                                      suggestion,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 16),
                                                    ),
                                                  );
                                                },
                                                onSelected:
                                                    (String selectedState) {
                                                  final selectedStateData =
                                                      stateList.firstWhere(
                                                    (item) =>
                                                        item['stateName'] ==
                                                        selectedState,
                                                  );

                                                  selectedStateCode =
                                                      selectedStateData[
                                                          'stateCd'];
                                                  selectedStateName =
                                                      selectedState;
                                                  subGroupController.text =
                                                      selectedState;

                                                  state = selectedStateName!;
                                                  stateCode =
                                                      selectedStateCode!;

                                                  print(state);
                                                  print(stateCode);
                                                },
                                                builder: (context, controller,
                                                    focusNode) {
                                                  return TextField(
                                                    controller:
                                                        subGroupController,
                                                    // or just use `controller`
                                                    focusNode: subGroupFocus,
                                                    // or just use `focusNode`
                                                    decoration: InputDecoration(
                                                      labelText: 'Select State',
                                                      suffixIcon: Icon(Icons
                                                          .arrow_drop_down),
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  );
                                                },
                                              )),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    // isLoading
                                    //     ? CircularProgressIndicator(
                                    //         color: Colors.black,
                                    //         strokeWidth: 2.0,
                                    //       )
                                    //     : Padding(
                                    //         padding: const EdgeInsets.all(2.0),
                                    //         child: Column(
                                    //           mainAxisAlignment:
                                    //               MainAxisAlignment.center,
                                    //           children: [
                                    //             SizedBox(
                                    //               width: double.infinity,
                                    //               child:
                                    //                   DropdownButtonFormField<
                                    //                       String>(
                                    //                 isExpanded: true,
                                    //                 iconEnabledColor:
                                    //                     Colors.black,
                                    //                 decoration: InputDecoration(
                                    //                   labelText: 'Select State',
                                    //                   border:
                                    //                       OutlineInputBorder(),
                                    //                   contentPadding:
                                    //                       EdgeInsets.symmetric(
                                    //                           horizontal: 12,
                                    //                           vertical: 8),
                                    //                   focusedBorder:
                                    //                       OutlineInputBorder(
                                    //                     borderSide: BorderSide(
                                    //                         color: Color(
                                    //                             0XFF2c9ed9),
                                    //                         width: 2.0),
                                    //                   ),
                                    //                 ),
                                    //                 // hint: Text(
                                    //                 //   "Select State",
                                    //                 //   style: TextStyle(color: Colors.black),
                                    //                 // ),
                                    //                 value: selectedStateCode,
                                    //                 items:
                                    //                     stateList.map((firm) {
                                    //                   return DropdownMenuItem<
                                    //                       String>(
                                    //                     value: firm['stateCd'],
                                    //                     child: Text(
                                    //                         firm['stateName']),
                                    //                   );
                                    //                 }).toList(),
                                    //                 menuMaxHeight: 300,
                                    //                 onChanged:
                                    //                     (String? newValue) {
                                    //                   setState(() {
                                    //                     selectedStateCode =
                                    //                         newValue; // Update selected state code
                                    //                     // Update the selected state name
                                    //                     selectedStateName =
                                    //                         stateList
                                    //                             .firstWhere(
                                    //                       (firm) =>
                                    //                           firm['stateCd'] ==
                                    //                           newValue,
                                    //                       orElse: () =>
                                    //                           {'stateName': ''},
                                    //                     )['stateName'];
                                    //                     // Propagate the selected state code and name
                                    //                     state =
                                    //                         selectedStateName!;
                                    //                     stateCode =
                                    //                         selectedStateCode!;
                                    //                   });
                                    //                 },
                                    //               ),
                                    //             ),
                                    //           ],
                                    //         ),
                                    //       ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              cityFocusNode.unfocus();
                                              stateFocusNode.unfocus();
                                              showPartySelectionMenu(
                                                  context); // Show the bottom sheet for state selection
                                            },
                                            child: AbsorbPointer(
                                              child: TextFormField(
                                                controller:
                                                    TextEditingController(
                                                        text:
                                                            selectedStateName),
                                                decoration: InputDecoration(
                                                  labelText: 'Select State',
                                                  //hintText: selectedStateName?.isEmpty ?? true ? 'State Name' : selectedStateName!,
                                                  // labelStyle: TextStyle(
                                                  //   fontSize: 16.0,
                                                  //   fontWeight: FontWeight.bold,
                                                  // ),
                                                  // hintStyle: TextStyle(
                                                  //   color: Colors.grey[400],
                                                  // ),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8),
                                                  border: OutlineInputBorder(),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color:
                                                            Color(0XFF8ac2e0),
                                                        width: 2.0),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (selectedStateName?.isNotEmpty ??
                                            false)
                                          const SizedBox(width: 10),
                                        if (selectedStateName?.isNotEmpty ??
                                            false)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                // Clear the selected state when the cancel button is tapped
                                                selectedStateName = '';
                                                selectedStateCode = '';
                                                state = '';
                                                stateCode = '';
                                              });
                                            },
                                            child: const Icon(Icons.close,
                                                size: 20),
                                          ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Visibility(
                                      visible: false,
                                      child: _buildTextField('State', state,
                                          (value) => state = value,
                                          focusNode: stateFocusNode,
                                          nextFocusNode: stateCodeFocusNode),
                                    ),
                                    Visibility(
                                      visible: false,
                                      child: _buildTextField(
                                          'State Code',
                                          stateCode,
                                          enabled: false,
                                          length: 2,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          (value) => stateCode = value,
                                          focusNode: stateCodeFocusNode,
                                          nextFocusNode: zoneFocusNode,
                                          keyboardType: TextInputType.number),
                                    ),

                                    _buildTextField(
                                        'Zone', zone, (value) => zone = value,
                                        focusNode: zoneFocusNode,
                                        nextFocusNode: pinCodeFocusNode,
                                    textInputAction: TextInputAction.next),
                                    _buildTextField(
                                        'Pin Code',
                                        pinCode,
                                        //length: 6,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        (value) => pinCode = value,
                                        focusNode: pinCodeFocusNode,
                                        textInputAction: TextInputAction.done,
                                        keyboardType: TextInputType.number),
                                  ],
                                ),
                                // GST Details section
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdownField(
                                            'GST Type',
                                            gstType,
                                            (value) {
                                              setState(() {
                                                gstType = value ?? '';
                                                gstNo = '';
                                              });
                                            },
                                            gstTypes,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Expanded(
                                          child: _buildTextField(
                                            'PAN No',
                                            panNo,
                                            (value) => panNo = value,
                                            //length: 10,
                                            validator: _validatePAN,
                                            focusNode: panNoFocusNode,
                                            nextFocusNode: gstNoFocusNode,
                                            inputFormatters: [
                                              LengthLimitingTextInputFormatter(
                                                  10),
                                              UpperCaseTextFormatter()
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildTextField(
                                      'GST No',
                                      gstNo,
                                      (value) {
                                        gstNo = value;
                                      },
                                      //length: 15,
                                      validator: (value) =>
                                          _validateGST(gstType, value),
                                      focusNode: gstNoFocusNode,
                                      nextFocusNode: fssaiNoFocusNode,
                                      inputFormatters: [
                                        LengthLimitingTextInputFormatter(15),
                                        UpperCaseTextFormatter()
                                      ],
                                    ),
                                    _buildTextField(
                                      'FSSAI No',
                                      fssaiNo,
                                      (value) => fssaiNo = value,
                                      focusNode: fssaiNoFocusNode,
                                      nextFocusNode: registrationNo1FocusNode,
                                      inputFormatters: [
                                        UpperCaseTextFormatter()
                                      ],
                                    ),
                                    _buildTextField(
                                      'Registration No 1',
                                      registrationNo1,
                                      (value) => registrationNo1 = value,
                                      focusNode: registrationNo1FocusNode,
                                      nextFocusNode: registrationNo2FocusNode,
                                      inputFormatters: [
                                        UpperCaseTextFormatter()
                                      ],
                                    ),
                                    _buildTextField(
                                      'Registration No 2',
                                      registrationNo2,
                                      (value) => registrationNo2 = value,
                                      focusNode: registrationNo2FocusNode,
                                      nextFocusNode: tcsAboveFocusNode,
                                      inputFormatters: [
                                        UpperCaseTextFormatter()
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDropdownField(
                                              'TCS Auto',
                                              tcsAuto,
                                              (value) => tcsAuto = value ??
                                                  '', // Handle null case

                                              ['Yes', 'No']),
                                        ),
                                        SizedBox(
                                          width: 10,
                                        ),
                                        Expanded(
                                          child: _buildTextField(
                                              'TCS Above',
                                              tcsAbove.toString(),
                                              (value) => tcsAbove =
                                                  double.tryParse(value) ?? 0.0,
                                              focusNode: tcsAboveFocusNode,
                                              inputFormatters: [
                                                LengthLimitingTextInputFormatter(
                                                    15)
                                              ],
                                              nextFocusNode: tcsWithPanFocusNode),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTextField(
                                              'TCS With PAN',
                                              tcsWithPan,
                                              (value) => tcsWithPan = value,
                                              focusNode: tcsWithPanFocusNode,
                                              nextFocusNode:
                                                  tcsWithoutPanFocusNode,
                                              keyboardType:
                                                  TextInputType.number),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: _buildTextField(
                                              'TCS Without PAN',
                                              tcsWithoutPan,
                                              (value) => tcsWithoutPan = value,
                                              focusNode: tcsWithoutPanFocusNode,
                                              nextFocusNode: footer1FocusNode,
                                              keyboardType:
                                                  TextInputType.number),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: _buildTextField('Footer 1',
                                          footer1, (value) => footer1 = value,
                                          focusNode: footer1FocusNode,
                                          nextFocusNode: footer2FocusNode),
                                    ),
                                    Flexible(
                                      child: _buildTextField('Footer 2',
                                          footer2, (value) => footer2 = value,
                                          focusNode: footer2FocusNode,
                                          nextFocusNode: footer3FocusNode),
                                    ),
                                    Flexible(
                                      child: _buildTextField('Footer 3',
                                          footer3, (value) => footer3 = value,
                                          focusNode: footer3FocusNode,
                                          nextFocusNode: footer4FocusNode),
                                    ),
                                    Flexible(
                                      child: _buildTextField('Footer 4',
                                          footer4, (value) => footer4 = value,
                                          focusNode: footer4FocusNode,
                                          nextFocusNode: footer5FocusNode),
                                    ),
                                    Flexible(
                                      child: _buildTextField('Footer 5',
                                          footer5, (value) => footer5 = value,
                                          focusNode: footer5FocusNode,
                                          textInputAction:
                                              TextInputAction.done),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Fixed position button
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0XFF2c9ed9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
