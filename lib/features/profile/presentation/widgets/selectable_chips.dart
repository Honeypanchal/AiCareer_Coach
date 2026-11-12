import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SelectableChips extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool multi;

  const SelectableChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.multi = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isOn = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isOn,
          onSelected: (_) => onToggle(option),
          showCheckmark: multi,
          selectedColor: AppColors.primary.withValues(alpha: 0.18),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            fontWeight: isOn ? FontWeight.w600 : FontWeight.w500,
            color: isOn ? AppColors.primary : null,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isOn ? AppColors.primary : Theme.of(context).dividerColor,
          ),
          backgroundColor: Colors.transparent,
        );
      }).toList(),
    );
  }
}
