
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ErrorPageScreen extends StatefulWidget {
  @override
  State<ErrorPageScreen> createState() => _ErrorPageScreenState();
}

class _ErrorPageScreenState extends State<ErrorPageScreen> {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image.asset("assets/update.gif"),
                const Text(
                  'Server Error',
                  style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(
                  height: 16.0,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18.0, vertical: 10.0),
                  child: const Text(
                    'The server is temporarily unable to service your request due to maintenance downtime or internal server Problem. Please try again later.',
                    style:
                        TextStyle(fontSize: 16.0, fontWeight: FontWeight.w400),
                  ),
                ),
                SizedBox(
                  height: 20.h,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
