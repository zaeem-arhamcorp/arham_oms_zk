import 'package:flutter/material.dart';


class CommonButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisable;

  const CommonButton({
    super.key,
    required this.buttonText,
    required this.onPressed,
    required this.isLoading,
    this.isDisable = false,
  });

  @override
  Widget build(BuildContext context) {
    //ThemeData theme = Theme.of(context);
    //Color buttonColor = isLoading ? Colors.grey : theme.primaryColor;
    //Color textColor =
    //    isLoading ? theme.disabledColor : theme.colorScheme.onPrimary;

    // Apply a blur effect if the button is disabled
    return AbsorbPointer(
      absorbing: isDisable,
      child: Opacity(
        opacity: isDisable ? 0.5 : 1.0,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(10), // Rounded corners
              ),
              backgroundColor: Color(0XFF2c9ed9),
              minimumSize:
              Size(double.infinity, 40), // Full-width button
            ),
            child: isLoading
                ? const SizedBox(
                    width: 25,
                    height: 25,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    buttonText,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400),
                  ),
          ),
        ),
      ),
    );
  }
}
