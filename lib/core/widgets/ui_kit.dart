import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Small building blocks shared by the screens, so every page has the same
// cards, badges, headers and buttons.

/// A gradient from a single brand color: a lighter tint into the color.
LinearGradient gradientFrom(Color color) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color.lerp(color, Colors.white, 0.28)!, color],
);

/// A rounded card with a hairline border. Tappable when [onTap] is set.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 22,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? AppColors.card(context) : null,
          gradient: gradient,
          borderRadius: shape,
          border: gradient == null
              ? Border.all(color: borderColor ?? AppColors.border(context))
              : null,
          boxShadow: AppColors.isDark(context)
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF2A2470).withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A white icon on a gradient rounded square, with a soft glow.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double size;
  final bool glow;

  const IconBadge({
    super.key,
    required this.icon,
    this.gradient = AppGradients.primary,
    this.size = 44,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = gradient.colors.last;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// A section heading with an optional action on the right ("See all").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// A full-width primary button filled with the brand gradient.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final shape = BorderRadius.circular(16);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: shape,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: shape,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft colored glow used to decorate hero cards and backgrounds.
class GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const GlowCircle({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// A small rounded label, e.g. "Medium" or "3 sessions".
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool onGradient;

  const Pill({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.icon,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onGradient ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onGradient
            ? Colors.white.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen background with two soft brand glows (sign-in screens).
class BrandBackground extends StatelessWidget {
  final Widget child;

  const BrandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    // expand: fill the whole screen so the glows are never cut off.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -160,
          left: -120,
          child: GlowCircle(
            size: 420,
            color: AppColors.primary.withValues(alpha: dark ? 0.28 : 0.16),
          ),
        ),
        Positioned(
          bottom: -180,
          right: -140,
          child: GlowCircle(
            size: 420,
            color: AppColors.pink.withValues(alpha: dark ? 0.16 : 0.10),
          ),
        ),
        child,
      ],
    );
  }
}
