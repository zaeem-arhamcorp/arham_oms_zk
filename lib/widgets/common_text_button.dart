import 'package:arham_corporation/widgets/common_text.dart';
import 'package:flutter/material.dart';

class CommonTextButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final bool underline;
  final Color? color;

  const CommonTextButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.underline = false, // 👈 default no underline
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 25),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: CommonText(
        text: title,
        // textAlign: TextAlign.center,
        // fontSize: AppDimensions.fontSizeMedium,
        // fontWeight: FontWeight.w400
        //color: underline ? null : Theme.of(context).colorScheme.primary,
        //color: underline ? Colors.red : null,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        color: color,
      ),
    );
  }
}
