import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions; // Added actions property

  CustomAppBar(
      {required this.title,
      this.actions =
          const []}); // Default to empty list if no actions are provided

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
      // backgroundColor: Color(0XFF2c9ed9),
      backgroundColor: Colors.transparent,
      elevation: 4,
      iconTheme: IconThemeData(color: Colors.white), // Set icon color to white
      actions: actions, // Use the passed actions here
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B82F6),
              Color(0xFF0057E7),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
