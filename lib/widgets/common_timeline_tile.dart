import 'package:flutter/material.dart';

class CommonTimelineTile extends StatelessWidget {
  final String date;
  final String time;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  const CommonTimelineTile({
    super.key,
    required this.date,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE (Date + Time)
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(time),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // CENTER (Line + Dot)
          Column(
            children: [
              // Top line
              Container(
                width: 2,
                height: isFirst ? 0 : 10,
                color: Colors.grey,
              ),

              // Dot
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),

              // Bottom line
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(width: 10),

          // RIGHT SIDE (Content)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Logged In",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(title),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
