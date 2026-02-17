import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:arham_corporation/generated/assets.dart';
import 'package:get/get.dart';

import '../widgets/bottomnavebar.dart';

class OrderConformationPage extends StatefulWidget {
  const OrderConformationPage({Key? key}) : super(key: key);

  @override
  State<OrderConformationPage> createState() => _OrderConformationPageState();
}

class _OrderConformationPageState extends State<OrderConformationPage> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 3)).then((value) {
      Get.offAll(() => BottomnavigationBarScreen());
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        height: size.height,
        width: size.width,
        decoration: BoxDecoration(color: Colors.green),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              Assets.assetsCheck,
              height: 180.h,
            ),
            SizedBox(
              height: 15,
            ),
            Text(
              "ThankYou!",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            SizedBox(
              height: 15,
            ),
            Text(
              "Your order has been placed.",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
