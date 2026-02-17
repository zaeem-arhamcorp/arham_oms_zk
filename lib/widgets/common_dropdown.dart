import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

class CommonDropdown extends StatelessWidget {
  final List<String> items;
  final String? initialValue;
  final String hint;
  final void Function(String?) onChanged;

  const CommonDropdown({
    Key? key,
    required this.items,
    this.initialValue,
    required this.hint,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          hint,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        value: items.contains(initialValue) ? initialValue : null,
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
        ),
      ),
    );
  }
}

