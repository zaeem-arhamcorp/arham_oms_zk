import 'package:flutter/material.dart';

import '../../models/firm_model.dart';
import '../../widgets/custom_app_bar.dart';

class FirmDetailsPage extends StatelessWidget {
  final FirmModel company;

  FirmDetailsPage(this.company);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: 'Company Details'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: <Widget>[
              _buildCompanyHeader(context),
              _buildSectionTitle('Address'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${company.address1}',
                        style: TextStyle(color: Colors.black)),
                    if (company.address2.isNotEmpty)
                      Text('${company.address2}',
                          style: TextStyle(color: Colors.black)),
                    if (company.address3.isNotEmpty)
                      Text('${company.address3}',
                          style: TextStyle(color: Colors.black)),
                    if (company.address4.isNotEmpty)
                      Text('${company.address4}',
                          style: TextStyle(color: Colors.black)),
                    if (company.address5.isNotEmpty)
                      Text('${company.address5}',
                          style: TextStyle(color: Colors.black)), // New field
                    Text(
                        '${company.firmCity}, ${company.firmState}, ${company.firmStateCode}',
                        style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
              _buildSectionTitle('Contact Details'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Mobile 1', company.firmMobile1), // Updated
                    _buildDetailRow('Mobile 2', company.firmMobile2), // Updated
                    _buildDetailRow(
                        'Contact Person', company.firmPersonName), // Updated
                    _buildDetailRow('Email ID', company.firmEmailId), // Updated
                    _buildDetailRow('UPI ID', company.firmUpi), // Updated
                  ],
                ),
              ),
              _buildSectionTitle('GST Details'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('GST No', company.firmGstNo), // Updated
                    _buildDetailRow('GST Type', company.firmGstType), // Updated
                    _buildDetailRow('PAN No', company.firmPanNo), // Updated
                    _buildDetailRow('FSSAI No', company.firmFssaiNo), // Updated
                    _buildDetailRow('Registration No 1',
                        company.firmRegistrationNo1), // Updated
                    _buildDetailRow('Registration No 2',
                        company.firmRegistrationNo2), // Updated
                  ],
                ),
              ),
              _buildSectionTitle('Additional Information'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                        'TCS With PAN',
                        company.tcsWithPan
                            .toString()), // Changed to display double value
                    _buildDetailRow(
                        'TCS Without PAN',
                        company.tcsWithoutPan
                            .toString()), // Changed to display double value
                    _buildDetailRow(
                        'TCS Auto', company.tcsAuto), // Remains a String
                    _buildDetailRow('TCS Above', company.tcsAbove.toString()),
                  ],
                ),
              ),
              _buildSectionTitle('Footers'),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Footer 1', company.footer1),
                    _buildDetailRow('Footer 2', company.footer2),
                    _buildDetailRow('Footer 3', company.footer3),
                    _buildDetailRow('Footer 4', company.footer4),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyHeader(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Company Name:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              company.firmName, // Updated
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.info, color: Color(0XFF8ac2e0)),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0XFF8ac2e0)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(width: 10),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
