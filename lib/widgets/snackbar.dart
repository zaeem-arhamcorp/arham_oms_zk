import 'package:flutter/material.dart';
//import 'package:fluttertoast/fluttertoast.dart';

//final FToast fToast = FToast();

void showAnimatedToast({required String message, required Color color}) {
  // Widget toast = StatefulBuilder(
  //   builder: (context, setState) {
  //     return TweenAnimationBuilder(
  //       tween: Tween<double>(begin: -50, end: 0), // Animation starts off-screen
  //       duration: const Duration(milliseconds: 500), // Animation duration
  //       builder: (context, value, child) {
  //         return Transform.translate(
  //           offset: Offset(0, value),
  //           child: Container(
  //             padding:
  //                 const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
  //             decoration: BoxDecoration(
  //               color: color,
  //               borderRadius:
  //                   BorderRadius.circular(8.0), // Slightly rounded corners
  //             ),
  //             child: Text(
  //               message,
  //               style: const TextStyle(color: Colors.white, fontSize: 16.0),
  //               textAlign: TextAlign.center,
  //             ),
  //           ),
  //         );
  //       },
  //     );
  //   },
  // );

  // fToast.showToast(
  //   child: toast,
  //   toastDuration: const Duration(seconds: 3),
  // );
}
