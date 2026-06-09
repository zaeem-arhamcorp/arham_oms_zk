import 'package:arham_corporation/views/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

//#2596be

class IntroPage extends StatelessWidget {
  // final ProductController productController = Get.put(ProductController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Image.asset(
              "assets/get_started_img.png",
              fit: BoxFit.fill,
              width: double.infinity,
            ),
            Container(
              padding: EdgeInsets.only(bottom: 50),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Expanded(child: Image.asset('assets/intro_img.png')),
                  SizedBox(
                    width: double.infinity,
                    height: 80.0,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          bottom: 25.0, left: 18.0, right: 18.0),
                      child: ElevatedButton(
                        onPressed: () {
                          Get.offAll(() => LoginPage());
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Color(0xff2c4ea5),
                          backgroundColor: Color(0xfff6f6f9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22.0),
                          ),
                        ),
                        // style: ButtonStyle(
                        //   backgroundColor: ,
                        //     // backgroundColor: Color(0xffd9e1e9),
                        //     // foregroundColor: Color(0xff2c4ea5),
                        //     shape:
                        //         WidgetStateProperty.all<RoundedRectangleBorder>(
                        //             RoundedRectangleBorder(
                        //   borderRadius: BorderRadius.circular(22.0),

                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Get Started",
                            style: TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff2c4ea5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
