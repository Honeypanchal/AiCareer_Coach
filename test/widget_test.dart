import 'package:ai_career_coach/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('themeModeLabel maps each ThemeMode', () {
    expect(themeModeLabel(ThemeMode.system), 'System');
    expect(themeModeLabel(ThemeMode.light), 'Light');
    expect(themeModeLabel(ThemeMode.dark), 'Dark');
  });
}
