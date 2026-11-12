import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows an error message: red icon and red text on the card colour,
/// the same in light and dark mode. Use this for every error snackbar.
void showErrorSnackBar(BuildContext context, String message) {
  _show(
    context,
    message,
    color: AppColors.error,
    icon: Icons.error_outline_rounded,
  );
}

/// Shows a success message with a green icon.
void showSuccessSnackBar(BuildContext context, String message) {
  _show(
    context,
    message,
    color: AppColors.success,
    icon: Icons.check_circle_outline_rounded,
  );
}

void _show(
  BuildContext context,
  String message, {
  required Color color,
  required IconData icon,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  // The bright pink-red is hard to read on white, so light mode uses a
  // deeper shade of the same colour.
  if (!isDark && color == AppColors.error) color = AppColors.errorOnLight;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
