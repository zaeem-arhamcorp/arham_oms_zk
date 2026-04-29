import 'dart:convert';

import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/firm_model.dart'; // Make sure this import is correct
import '../../providers/user_provider.dart';
import '../../widgets/add_firm_form.dart';

class AddFirmPage extends StatefulWidget {
  final Function
      refreshList; // Callback function to refresh the list after adding a company

  const AddFirmPage({Key? key, required this.refreshList}) : super(key: key);

  @override
  State<AddFirmPage> createState() => _AddFirmPageState();
}

class _AddFirmPageState extends State<AddFirmPage> {
  late UserProvider _userProvider;
  late FirmModel initialCompany;

  @override
  void initState() {
    super.initState();
    initialCompany = FirmModel.empty(); // Use the empty constructor
  }

  @override
  void didChangeDependencies() {
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    super.didChangeDependencies();
  }

  Future<void> _submitCompany(FirmModel company) async {
    final url = Uri.parse(AppConfig.baseURL + 'firm');

    try {
      Map<String, dynamic> payload = {
        "firmName": company.firmName,
        "add1": company.address1,
        "add2": company.address2,
        "add3": company.address3,
        "add4": company.address4,
        "add5": company.address5,
        "city": company.firmCity,
        "state": company.firmState,
        "stateCode": company.firmStateCode,
        "zone": company.firmZone,
        "pincode": company.pinCode,
        "mobile1": company.firmMobile1,
        "mobile2": company.firmMobile2,
        "personNm": company.firmPersonName,
        "email": company.firmEmailId,
        "upi": company.firmUpi,
        "gstNo": company.firmGstNo,
        "gstType": company.firmGstType,
        "panNo": company.firmPanNo,
        "fssaiNo": company.firmFssaiNo,
        "regNo1": company.firmRegistrationNo1,
        "regNo2": company.firmRegistrationNo2,
        "tcsWithPan": company.tcsWithPan.toStringAsFixed(2),
        "tcsWithoutPan": company.tcsWithoutPan.toStringAsFixed(2),
        "tcsAuto": company.tcsAuto,
        "tcsAbove": company.tcsAbove.toStringAsFixed(2),
        "footer1": company.footer1,
        "footer2": company.footer2,
        "footer3": company.footer3,
        "footer4": company.footer4,
        "footer5": company.footer5,
      };

      print(payload);

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${_userProvider.token!}",
          'Content-Type': 'application/json',
          'x-app-type': 'oms',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Company added successfully!',
            backgroundColor: Colors.green);
        widget.refreshList(); // Call the callback to refresh the list
        Navigator.pop(context); // Navigate back on success
      } else {
        AppSnackBar.showGetXCustomSnackBar(
            message:
                'Failed to add company: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'An error occurred: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: 'Add Company'),
      body: SafeArea(
        child: AddFirmForm(
          initialCompany: initialCompany,
          onSubmit: _submitCompany,
        ),
      ),
    );
  }
}
