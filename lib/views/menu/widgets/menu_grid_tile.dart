import 'package:flutter/material.dart';

class MenuGridTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String? iconUrl;
  final String label;

  const MenuGridTile({
    super.key,
    this.icon,
    this.iconColor,
    this.iconUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double iconSize =
            constraints.maxWidth * 0.30; // Adjust the multiplier as needed

        return Card(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.black.withOpacity(0.05),
              //     blurRadius: 4,
              //     offset: const Offset(0, 2),
              //   ),
              // ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      // color: const Color(0xFF0057E7).withOpacity(.08),
                      color: iconColor?.withOpacity(.08),
                      borderRadius: BorderRadius.circular(444),
                    ),
                    child: iconUrl != null
                        ? Image.asset(
                            iconUrl!,
                            width: iconSize,
                            height: iconSize,
                            color: iconColor, // optional
                          )
                        : Icon(
                            icon,
                            color: iconColor,
                            size: iconSize,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
