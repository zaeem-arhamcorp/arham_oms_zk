import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    // Get the screen width and height
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: CustomAppBar(
          title: 'About Arham Corp.',
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'At Arham Corp., we don’t just provide software solutions — we provide intelligent systems that'
                  ' transform the way your business operates\n\nOur expertise in :-',
                  style: TextStyle(fontSize: screenWidth * 0.045),
                ),
                _buildBulletPoint(
                    'Order Management Systems (OMS)', screenWidth),
                _buildBulletPoint(
                    'Enterprise Resource Planning (ERP)', screenWidth),
                _buildBulletPoint(
                    'Invoice Management Systems (IMS)', screenWidth),
                _buildBulletPoint('Point of Sale (POS)', screenWidth),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Why Choose Arham Corp?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF2c9ed9),
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildBulletPoint(
                    'Tailored Solutions for Your Business Needs', screenWidth),
                _buildBulletPoint(
                    'Real-Time Sales Tracking and Monitoring', screenWidth),
                _buildBulletPoint(
                    'Multi-Firm, Multi-Branch, Multi-User  Support',
                    screenWidth),
                _buildBulletPoint(
                    'Comprehensive Reporting and Analytics', screenWidth),
                _buildBulletPoint(
                    'Barcode Scanning and Inventory Management', screenWidth),
                _buildBulletPoint('Security and Data Protection', screenWidth),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF2c9ed9),
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildContactInfo(
                  screenWidth,
                  screenHeight,
                  Icons.location_on_rounded,
                  'Arham Corporation',
                  'https://maps.app.goo.gl/8jd4n2zfc1iv6QZ19',
                  '420, 4th Floor, Sheetal Varsha - Mahavir Business Park, Near Jamalpur Cross Road, Ahmedabad-380022',
                ),
                _buildContactInfo(
                  screenWidth,
                  screenHeight,
                  Icons.call,
                  'Call Us',
                  'tel:+919173919797',
                  '+91 917391 9797',
                ),
                _buildContactInfo(
                  screenWidth,
                  screenHeight,
                  Icons.alternate_email,
                  'Email Us',
                  'mailto:info@arhamcorp.in',
                  'info@arhamcorp.in',
                ),
                _buildContactInfo(
                  screenWidth,
                  screenHeight,
                  Icons.search,
                  'Visit On',
                  'https://arhamcorp.in',
                  'arhamcorp.in.in',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.double_arrow, size: screenWidth * 0.05),
          SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(double screenWidth, double screenHeight,
      IconData icon, String label, String url, String value) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          throw 'Could not launch $url';
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _getIconColor(icon), size: screenWidth * 0.06),
              SizedBox(width: 8.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Color(0XFF2c9ed9),
                ),
              ),
            ],
          ),
          Text(value, style: TextStyle(fontSize: screenWidth * 0.04)),
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }

  Color _getIconColor(IconData icon) {
    if (icon == Icons.location_on_rounded) {
      return Colors.red;
    } else if (icon == Icons.call) {
      return Colors.green;
    } else if (icon == Icons.alternate_email) {
      return Colors.grey;
    } else {
      return Colors.orange;
    }
  }
}
