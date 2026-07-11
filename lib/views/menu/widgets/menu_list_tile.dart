import 'package:flutter/material.dart';

class MenuListTile extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String? iconUrl;
  final String label;
  final VoidCallback onTap;

  const MenuListTile({
    super.key,
    this.icon,
    this.iconColor,
    this.iconUrl,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      // margin: const EdgeInsets.symmetric(
      //   horizontal: 8,
      //   vertical: 4,
      // ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  // color: const Color(0xFF0057E7).withOpacity(.08),
                  color: iconColor?.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: iconUrl != null
                      ? Image.asset(
                          iconUrl!,
                          width: 24,
                          // color: Color(0xFF0057E7),
                          color: iconColor,
                        )
                      : Icon(
                          icon,
                          // color: Color(0xFF0057E7),
                          color: iconColor,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
