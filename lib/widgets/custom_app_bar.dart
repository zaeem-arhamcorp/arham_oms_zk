import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions; // Added actions property

  CustomAppBar({required this.title, this.actions = const []}); // Default to empty list if no actions are provided

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 22,
          color: Colors.white,
        ),
      ),
      centerTitle: false,
      backgroundColor: Color(0XFF2c9ed9),
      elevation: 4,
      iconTheme: IconThemeData(color: Colors.white), // Set icon color to white
      actions: actions, // Use the passed actions here
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
