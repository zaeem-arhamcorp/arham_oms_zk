import 'package:flutter/material.dart';

import '../helper/helper.dart';

class Box extends StatelessWidget {
  const Box({Key? key}) : super(key: key);

  get data => null;

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.only(left: 8,top: 60),
      child: Container(
        width: screenWidth * 0.5, // Half of the screen width
        height: screenHeight * 0.25, // One-fourth of the screen height
        decoration: BoxDecoration(
          color: Colors.blue[100],
          border: Border.all(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
      children: data!.overview.inventory
          .where((item) => item.LABEL == "Sales") // Filter items where LABEL is "Sales"
        .map((salesItem) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "${salesItem.LABEL}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red, // Highlight label text for "Sales"
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  "(${salesItem.RECORD})",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          "₹ ${Helper.parseNumericValue(salesItem.VOUCH_AMT)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red, // Highlight the amount for "Sales"
          ),
        ),
      ],
    ))
        .toList(),
    )

    ),
    );
  }

  // ignore: unused_element
  Widget _buildInnerBox(Color color) {
    return Container(
      width: double.infinity, // Stretch to fill the horizontal space
      height: 40.0, // Fixed height for each inner box
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
