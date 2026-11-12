import 'package:ai_career_coach/core/theme/app_theme.dart';
import 'package:ai_career_coach/core/theme/theme_controller.dart';
import 'package:ai_career_coach/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _showError(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showErrorSnackBar(context, 'Something failed'),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  test('themeModeLabel maps each ThemeMode', () {
    expect(themeModeLabel(ThemeMode.system), 'System');
    expect(themeModeLabel(ThemeMode.light), 'Light');
    expect(themeModeLabel(ThemeMode.dark), 'Dark');
  });

  testWidgets('error snackbar text is red in dark mode', (tester) async {
    await _showError(tester, AppTheme.darkTheme);
    final text = tester.widget<Text>(find.text('Something failed'));
    expect(text.style?.color, AppColors.error);
  });

  testWidgets('error snackbar text is a readable red in light mode',
      (tester) async {
    await _showError(tester, AppTheme.lightTheme);
    final text = tester.widget<Text>(find.text('Something failed'));
    expect(text.style?.color, AppColors.errorOnLight);
  });
}
