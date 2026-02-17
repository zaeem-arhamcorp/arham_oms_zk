import 'dart:convert';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../models/firm_model.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import 'add_firm.dart';
import 'firm_details.dart';
import 'edit_firm.dart';
import 'package:http/http.dart' as http;

class FirmListPage extends StatefulWidget {
  @override
  _FirmListPageState createState() => _FirmListPageState();
}

class _FirmListPageState extends State<FirmListPage> {
  List<Map<String, dynamic>> firmList = [];
  bool isLoading = true;
  int maxFirms = 0;

  @override
  void initState() {
    super.initState();
    fetchFirmData(); // Fetch firm data initially

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ProfileProvider p =
      Provider.of<ProfileProvider>(context, listen: false);
      p.getProfile(context).then((value) {
        setState(() {
          maxFirms = p.data?.license?.maxFirms ?? 0; // Safely access maxFirms
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Company List',
        actions: [
          IconButton(
            onPressed: () {
              if (firmList.length >= maxFirms) {
                // Fluttertoast.showToast(
                //     msg:
                //         'Firm limit reached! You cannot add more than $maxFirms firms.');
                AppSnackBar.showGetXCustomSnackBar(message: 'Firm limit reached! You cannot add more than $maxFirms firms.');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddFirmPage(refreshList: fetchFirmData),
                  ),
                );
              }
            },
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator()) // Show loading indicator
              : ListView.builder(
                  itemCount: firmList.length,
                  itemBuilder: (context, index) {
                    var firm = firmList[index];
                    return Card(
                      elevation: 4,
                      color: Colors.white,
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text(
                          firm['FIRM_NAME'],
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("${firm['MOBILE1']}, ${firm['MOBILE2']}"),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FirmDetailsPage(FirmModel(
                                firmID: firm['FIRM_ID'] ?? '',
                                firmName: firm['FIRM_NAME'] ?? '',
                                address1: firm['ADD1'] ?? '',
                                address2: firm['ADD2'] ?? '',
                                address3: firm['ADD3'] ?? '',
                                address4: firm['ADD4'] ?? '',
                                address5: firm['ADD5'] ?? '',
                                // Include new field
                                firmCity: firm['CITY'] ?? '',
                                firmState: firm['STATE'] ?? '',
                                firmStateCode: firm['STATE_CODE'] ?? '',
                                firmZone: firm['ZONE'] ?? '',
                                firmMobile1: firm['MOBILE1'] ?? '',
                                firmMobile2: firm['MOBILE2'] ?? '',
                                firmPersonName: firm['PERSON_NM'] ?? '',
        
                                firmEmailId: firm['EMAIL_ID'] ?? '',
                                firmUpi: firm['UPI'] ?? '',
                                firmGstNo: firm['GST_NO'] ?? '',
                                firmGstType: firm['GST_TYPE'] ?? '',
                                // GST Type as a String
                                firmPanNo: firm['PAN_NO'] ?? '',
                                firmFssaiNo: firm['FSSAI_NO'] ?? '',
                                firmRegistrationNo1: firm['REG_NO_1'] ?? '',
                                // Updated
                                firmRegistrationNo2: firm['REG_NO_2'] ?? '',
                                // Updated
                                tcsWithPan: firm['TCS_WITH_PAN'] is int
                                    ? (firm['TCS_WITH_PAN'] as int).toDouble()
                                    : double.tryParse(
                                            firm['TCS_WITH_PAN']?.toString() ??
                                                '') ??
                                        0.0,
                                // Convert back to double
                                tcsWithoutPan: firm['TCS_WITHOUT_PAN'] is int
                                    ? (firm['TCS_WITHOUT_PAN'] as int).toDouble()
                                    : double.tryParse(
                                            firm['TCS_WITHOUT_PAN']?.toString() ??
                                                '') ??
                                        0.0,
                                // Convert back to double
                                tcsAuto: firm['TCS_AUTO'] ?? '',
                                // Remains a String
                                tcsAbove: firm['TCS_ABOVE'] is int
                                    ? (firm['TCS_ABOVE'] as int).toDouble()
                                    : double.tryParse(
                                            firm['TCS_ABOVE']?.toString() ??
                                                '') ??
                                        0.0,
                                createdAt: DateTime.now(),
                                // Include timestamp
                                footer1: firm['FOOTER1'] ?? '',
                                footer2: firm['FOOTER2'] ?? '',
                                footer3: firm['FOOTER3'] ?? '',
                                footer4: firm['FOOTER4'] ?? '',
                                footer5: firm['FOOTER5'] ?? '',
                                pinCode:
                                    firm['PINCODE'] ?? '', // Include Pin Code
                              )),
                            ),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return EditFirmPage(
                                          refreshList: fetchFirmData,
                                          // Callback function to refresh the list
                                          company: FirmModel(
                                            firmID: firm['FIRM_ID'] ?? '',
                                            firmName: firm['FIRM_NAME'] ?? '',
                                            address1: firm['ADD1'] ?? '',
                                            address2: firm['ADD2'] ?? '',
                                            address3: firm['ADD3'] ?? '',
                                            address4: firm['ADD4'] ?? '',
                                            address5: firm['ADD5'] ?? '',
                                            // Include new field
                                            firmCity: firm['CITY'] ?? '',
                                            firmState: firm['STATE'] ?? '',
                                            firmStateCode:
                                                firm['STATE_CODE'] ?? '',
                                            firmZone: firm['ZONE'] ?? '',
                                            firmMobile1: firm['MOBILE1'] ?? '',
                                            firmMobile2: firm['MOBILE2'] ?? '',
                                            firmPersonName:
                                                firm['PERSON_NM'] ?? '',
        
                                            firmEmailId: firm['EMAIL_ID'] ?? '',
                                            firmUpi: firm['UPI'] ?? '',
                                            firmGstNo: firm['GST_NO'] ?? '',
                                            firmGstType: firm['GST_TYPE'] ?? '',
                                            // GST Type as a String
                                            firmPanNo: firm['PAN_NO'] ?? '',
                                            firmFssaiNo: firm['FSSAI_NO'] ?? '',
                                            firmRegistrationNo1:
                                                firm['REG_NO_1'] ?? '',
                                            // Updated
                                            firmRegistrationNo2:
                                                firm['REG_NO_2'] ?? '',
                                            // Updated
                                            tcsWithPan: firm['TCS_WITH_PAN']
                                                    is int
                                                ? (firm['TCS_WITH_PAN'] as int)
                                                    .toDouble()
                                                : double.tryParse(
                                                        firm['TCS_WITH_PAN']
                                                                ?.toString() ??
                                                            '') ??
                                                    0.0,
                                            // Convert back to double
                                            tcsWithoutPan: firm['TCS_WITHOUT_PAN']
                                                    is int
                                                ? (firm['TCS_WITHOUT_PAN'] as int)
                                                    .toDouble()
                                                : double.tryParse(
                                                        firm['TCS_WITHOUT_PAN']
                                                                ?.toString() ??
                                                            '') ??
                                                    0.0,
                                            // Convert back to double
                                            tcsAuto: firm['TCS_AUTO'] ?? '',
                                            // Remains a String
                                            tcsAbove: firm['TCS_ABOVE'] is int
                                                ? (firm['TCS_ABOVE'] as int)
                                                    .toDouble()
                                                : double.tryParse(
                                                        firm['TCS_ABOVE']
                                                                ?.toString() ??
                                                            '') ??
                                                    0.0,
                                            createdAt: DateTime.now(),
                                            // Include timestamp
                                            footer1: firm['FOOTER1'] ?? '',
                                            footer2: firm['FOOTER2'] ?? '',
                                            footer3: firm['FOOTER3'] ?? '',
                                            footer4: firm['FOOTER4'] ?? '',
                                            footer5: firm['FOOTER5'] ?? '',
                                            pinCode: firm['PINCODE'] ??
                                                '', // Include Pin Code
                                          ),
                                          firmId: firm['FIRM_ID'] ?? '');
                                    },
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              color: Colors.red,
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Delete Firm'),
                                      content: Text.rich(
                                        TextSpan(
                                          text:
                                              'Are you sure you want to delete this firm?\n',
                                          style: TextStyle(fontSize: 16),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: firm['FIRM_NAME'],
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context)
                                                .pop(); // Close the dialog
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            final custId = firm[
                                                'CUST_ID']; // Corrected to match the key name
                                            final firmId = firm[
                                                'FIRM_ID']; // Corrected to match the key name
        
                                            if (custId == null ||
                                                custId.isEmpty) {
                                              // Fluttertoast.showToast(
                                              //   msg:
                                              //       "Customer ID is missing for this firm.",
                                              // );
                                              AppSnackBar.showGetXCustomSnackBar(message: 'Customer ID is missing for this firm.');
        
                                              return; // Prevent deletion if custId is missing
                                            }
        
                                            deleteFirm(
                                              context,
                                              firmId, // Pass firmId
                                              //custId, // Pass custId
                                            );
                                            // Close the dialog after deletion
                                          },
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // Fetch firm data
  Future<void> fetchFirmData() async {
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          firmList = List<Map<String, dynamic>>.from(data['data']);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      //Fluttertoast.showToast(msg: "Error fetching data: $e");
      AppSnackBar.showGetXCustomSnackBar(message: "Error fetching data: $e");
    }
  }

  // Delete a firm
  Future<void> deleteFirm(
      BuildContext context, String firmId) async {
    /*if (custId.isEmpty) {
      return;
    }*/

    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      //final Uri url = Uri.parse('${AppConfig.baseUrl}firm?firmId=$firmId');
      String url = '${AppConfig.baseURL}firm/$firmId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          'x-app-type': 'oms',
        },
        // body: jsonEncode({
        //   "custId": custId,
        // }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        Navigator.of(context).pop();
        //Fluttertoast.showToast(msg: "Firm deleted successfully!");
        AppSnackBar.showGetXCustomSnackBar(message: "Firm deleted successfully!",backgroundColor: Colors.green);
        fetchFirmData();
      } else {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final String message = responseBody['message'] ?? 'An error occurred.';
        //Fluttertoast.showToast(msg: message);
        AppSnackBar.showGetXCustomSnackBar(message: message);
      }
    } catch (e) {
      //Fluttertoast.showToast(msg: "Something went wrong: $e");
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong: $e");
    }
  }
}
