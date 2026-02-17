import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/widgets/edit_firm_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/firm_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../providers/user_provider.dart';
import 'package:http/http.dart' as http;

class EditFirmPage extends StatefulWidget {
  final Function
      refreshList; // Callback function to refresh the list after adding a company
  final FirmModel company; // Firm data passed from list screen
  final String firmId;

  const EditFirmPage(
      {Key? key,
      required this.refreshList,
      required this.company,
      required this.firmId})
      : super(key: key);

  @override
  State<EditFirmPage> createState() => _EditFirmPageState();
}

class _EditFirmPageState extends State<EditFirmPage> {
  late UserProvider _userProvider;

  @override
  void initState() {
    super.initState();
    print(widget.company);
  }

  @override
  void didChangeDependencies() {
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    super.didChangeDependencies();
  }

  Future<void> _updateCompany(FirmModel company) async {
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
        "firmId": widget.firmId,
        "footer1": company.footer1,
        "footer2": company.footer2,
        "footer3": company.footer3,
        "footer4": company.footer4,
        "footer5": company.footer5,
      };

      print(payload);

      final response = await http.put(
        url,
        headers: {
          "Authorization": "Bearer ${_userProvider.token!}",
          'Content-Type': 'application/json',
          'x-app-type': 'oms',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company update successfully!')),
        );
        widget.refreshList(); // Call the callback to refresh the list
        Navigator.pop(context); // Navigate back on success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to add company: ${response.statusCode} - ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: 'Edit Company'),
      body: SafeArea(
        child: EditFirmForm(
          initialCompany: widget.company,
          onSubmit: _updateCompany,
        ),
      ),
    );
  }
}
