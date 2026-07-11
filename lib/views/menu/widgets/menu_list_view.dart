import 'package:flutter/material.dart';

class MenuListView extends StatelessWidget {
  final List<Widget> items;

  const MenuListView({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.05),
          //     blurRadius: 4,
          //     spreadRadius: 4.0,
          //     // offset: const Offset(0, 2),
          //   ),
          // ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 0.5,
            indent: 70,
            endIndent: 10,
            color: Colors.grey[200],
          ),
          // const SizedBox(height: 8),
          itemBuilder: (context, index) => items[index],
        ),
      ),
    );
  }
}
