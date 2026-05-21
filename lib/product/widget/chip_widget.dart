import 'package:flutter/material.dart';

class SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final TextStyle selectedTextStyle;
  final TextStyle unselectedTextStyle;
  final Function(bool) onSelected;

  const SelectableChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.selectedTextStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    this.unselectedTextStyle = const TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.normal,
    ),
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: isSelected ? selectedTextStyle : unselectedTextStyle,
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: Colors.blue,
      backgroundColor: Colors.grey[300],
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(180),
      ),
    );
  }
}
