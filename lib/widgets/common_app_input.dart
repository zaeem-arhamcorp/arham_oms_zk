import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common app input used in whole app
class CommonAppInput extends StatelessWidget {
  final TextEditingController textEditingController;
  final TextInputType textInputType;
  final TextAlign? textAlign;
  final bool? isPassword;
  final double borderRadius;
  final String hintText;
  final String? labelText;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final IconData? suffixIcon;
  final IconData? prifixIcon;
  final Color? prifixColor;
  final Color? suffixColor;
  final VoidCallback? onSuffixClick;
  final VoidCallback? onPrifixClick;
  final TextInputAction textInputAction;
  final Function(String text)? onSubmitted;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String text)? onChanged;
  final Color borderColor;
  final Color? hintColor;
  final bool? isEnable;
  final EdgeInsets? padding;
  final EdgeInsets? prifixPadding;
  final int? maxLength;
  final int? maxLines;
  final String? suFixImage;
  final String? prifixImage;
  final double? inputHeight;
  final double? inputWidth;

  const CommonAppInput({
    super.key,
    required this.textEditingController,
    this.textInputType = TextInputType.text,
    this.textAlign,
    this.isPassword = false,
    this.borderRadius = 10,
    this.hintText = '',
    this.labelText, // 👈 ADD
    this.hintStyle,
    this.hintColor,
    this.labelStyle,
    this.suffixIcon,
    this.prifixIcon,
    this.onSuffixClick,
    this.onPrifixClick,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onEditingComplete,
    this.focusNode,
    this.nextFocusNode,
    this.inputFormatters,
    this.onChanged,
    this.isEnable,
    this.borderColor = Colors.black,
    this.padding,
    this.maxLength,
    this.maxLines,
    this.suFixImage,
    this.prifixImage,
    this.inputHeight,
    this.inputWidth,
    this.prifixPadding,
    this.prifixColor,
    this.suffixColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: inputHeight,
      width: inputWidth ?? double.infinity,
      child: TextFormField(
        onChanged: onChanged,
        textAlign: textAlign ?? TextAlign.start,
        focusNode: focusNode,
        controller: textEditingController,
        cursorColor: Colors.blue,
        keyboardType: textInputType,
        obscureText: isPassword ?? false,
        textInputAction: textInputAction,
        onFieldSubmitted: (String text) {
          onSubmitted?.call(text);
          nextFocusNode?.requestFocus();
        },
        onEditingComplete: onEditingComplete,
        style: labelStyle,
        inputFormatters: inputFormatters,
        enabled: isEnable,
        maxLength: maxLength,
        maxLines: maxLines ?? 1,
        decoration: InputDecoration(
          counter: const Offstage(),
          suffixIconConstraints: const BoxConstraints(minWidth: 16, minHeight: 39),
          suffixIcon: suffixIcon != null
              ? Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkResponse(
              radius: 12,
              onTap: onSuffixClick,
              child: Icon(
                suffixIcon,
                size: 20,
                color: suffixColor,
              ),
            ),
          )
              : suFixImage != null
              ? Padding(
            padding: const EdgeInsets.all(10),
            child: InkResponse(
              radius: 12,
              onTap: onSuffixClick,
              child: Image.asset(
                suFixImage!,
                height: 20,
                width: 20,
                color: suffixColor,
              ),
            ),
          )
              : null,
          prefixIcon: prifixIcon != null
              ? Padding(
            padding: prifixPadding ?? const EdgeInsets.only(left: 10),
            child: InkResponse(
              radius: 15,
              onTap: onPrifixClick,
              child: Icon(
                prifixIcon,
                size: 18,
                color: Colors.blue,
              ),
            ),
          )
              : prifixImage != null
              ? Padding(
            padding: prifixPadding ?? const EdgeInsets.only(left: 10),
            child: InkResponse(
              radius: 15,
              onTap: onPrifixClick,
              child: Image.asset(
                prifixImage!,
                height: 20,
                width: 20,
                color: prifixColor,
              ),
            ),
          )
              : null,
          labelText: labelText, // ✅ ADD THIS
          hintText: hintText,
          isDense: true,
          labelStyle: labelStyle ?? TextStyle(fontSize: 14, color: hintColor ?? borderColor),
          hintStyle: hintStyle ?? TextStyle(fontSize: 14, color: hintColor ?? borderColor),
          contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, style: BorderStyle.none, width: 1),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, style: BorderStyle.none, width: 1),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, style: BorderStyle.solid, width: 1),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue, style: BorderStyle.solid, width: 1),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

class StartWithAlphabetOrUnderscoreFormatter extends TextInputFormatter {
  final RegExp allowedRegExp =
  RegExp(r'^[A-Za-z_][A-Za-z0-9_ ]*$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Allow empty (so user can delete)
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Check full string pattern
    if (allowedRegExp.hasMatch(newValue.text)) {
      return newValue;
    }

    // Reject invalid input
    return oldValue;
  }
}

