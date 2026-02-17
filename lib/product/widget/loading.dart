import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  final double? size;
  final Color color;

  const Loading({
    super.key,
    this.size,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Center(
            child: CircularProgressIndicator(
              color: color,
            ),
          ),
        ));
  }
}
