import 'package:flutter/material.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:get/get.dart';

//#2596be

class IntroPage extends StatelessWidget {
  // final ProductController productController = Get.put(ProductController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //       colors: [
          //         const Color(0xFFFF9FFB),
          //         const Color(0xFFFAFAFA).withOpacity(0.3),
          //         const Color(0xFFFAFAFA).withOpacity(0.2),
          //         const Color(0xFF9599FF),
          //       ],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //       stops: [0.0, 0.3, 0.6, 1.0],
          //       tileMode: TileMode.decal),
          // ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Image.asset('assets/intro_img.png')),
              SizedBox(
                width: double.infinity,
                height: 80.0,
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 25.0, left: 18.0, right: 18.0),
                  child: ElevatedButton(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Get Started",
                          style: TextStyle(
                            fontSize: 23.0,
                          )),
                    ),
                    onPressed: () {
                      Get.offAll(() => LoginPage());
                    },
                    style: ButtonStyle(
                        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22.0),
                    ))),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
