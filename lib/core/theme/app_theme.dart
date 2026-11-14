import 'package:flutter/material.dart';

// ─── Color Palette ───────────────────────────────────────────────────────────
// One source of truth for colors. The names are used across the app, so they
// stay the same; the values were refined for the PrepPilot redesign.
class AppColors {
  // Brand: the violet of the PrepPilot logo.
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4B44CC);
  static const primaryLight = Color(0xFF9C8FFF);

  // Accents used in gradients and feature tiles.
  static const pink = Color(0xFFFF6FB5);
  static const cyan = Color(0xFF2EC5FF);
  static const amber = Color(0xFFFFB547);
  static const mint = Color(0xFF34D399);

  // Dark mode: deep navy instead of flat black.
  static const darkBg = Color(0xFF0B0B14); // screen background
  static const darkSurface = Color(0xFF151522); // inputs, bars
  static const darkCard = Color(0xFF1B1B2C); // cards
  static const darkBorder = Color(0xFF29293F);

  // Light mode: soft lavender.
  static const lightBg = Color(0xFFF6F6FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFEFEEFC);
  static const lightBorder = Color(0xFFE6E5F5);

  // Text
  static const textWhite = Color(0xFFF4F4FF);
  static const textGrey = Color(0xFF8E8EA9);
  static const textDark = Color(0xFF15152A);

  // Status
  static const success = Color(0xFF34C77B);
  static const error = Color(0xFFFF5C7D);
  static const errorOnLight = Color(0xFFD7264B); // error text on white
  static const warning = Color(0xFFFFB347);

  /// Red for error text, readable in both light and dark mode.
  static Color errorText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? error : errorOnLight;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Card background for the current theme.
  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightSurface;

  /// Hairline border for cards in the current theme.
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  /// Main text color for the current theme.
  static Color text(BuildContext context) =>
      isDark(context) ? textWhite : textDark;
}

// ─── Gradients ───────────────────────────────────────────────────────────────
class AppGradients {
  /// The brand gradient (logo, hero cards, primary buttons).
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7BFF), Color(0xFF5B4FE8)],
  );

  /// Hero card: violet into pink, for the most important card on a screen.
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B6CFF), Color(0xFF9E5CF0), Color(0xFFE065B5)],
    stops: [0, 0.55, 1],
  );

  // One gradient per feature, used on tiles and icon badges.
  static const chat = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7BFF), Color(0xFF5B4FE8)],
  );
  static const interview = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3EE6A5), Color(0xFF14A97A)],
  );
  static const resume = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC46B), Color(0xFFFF8A3D)],
  );
  static const profile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7DB8), Color(0xFFE5467F)],
  );
  static const info = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5ED3FF), Color(0xFF2E8BFF)],
  );
}

// ─── App Theme ───────────────────────────────────────────────────────────────
class AppTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final card = dark ? AppColors.darkCard : AppColors.lightSurface;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = dark ? AppColors.textWhite : AppColors.textDark;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.pink,
          surface: surface,
          onSurface: text,
          error: dark ? AppColors.error : AppColors.errorOnLight,
          outline: border,
          outlineVariant: border,
        );

    final roundedField = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,

      // ── Typography ──────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -1,
          height: 1.15,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -0.8,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: text, height: 1.5),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: AppColors.textGrey,
          height: 1.5,
        ),
        bodySmall: const TextStyle(fontSize: 12.5, color: AppColors.textGrey),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.1,
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: roundedField,
        enabledBorder: roundedField,
        focusedBorder: roundedField.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: roundedField.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: roundedField.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textGrey),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.textGrey,
        suffixIconColor: AppColors.textGrey,
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: dark
              ? const Color(0xFF26263A)
              : const Color(0xFFE4E3F3),
          disabledForegroundColor: AppColors.textGrey,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          // Brand gradient behind every enabled primary button.
          backgroundBuilder: (context, states, child) {
            if (states.contains(WidgetState.disabled)) return child!;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            );
          },
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary.withValues(alpha: dark ? 0.22 : 0.12)
                : card,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textGrey,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
          ),
        ),
      ),

      // ── Surfaces ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: AppColors.primary.withValues(alpha: dark ? 0.25 : 0.14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        checkmarkColor: AppColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textGrey,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
      ),

      // ── App Bar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.2,
        ),
      ),

      // ── Snackbar ────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.darkCard : AppColors.textDark,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
