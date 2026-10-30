import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // AnimationController drives all our animations
  late AnimationController _controller;

  // Two animations: logo fades+scales in, tagline fades in slightly later
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    // Controller runs for 1.5 seconds total
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Logo scales from 0.6 → 1.0 (bouncy feel using elasticOut curve)
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Logo fades in from 0 → 1 in the first 40% of the animation
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Tagline fades in from 40% → 80% of the animation (delayed after logo)
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    // Start the animation. GoRouter redirect leaves this screen
    // after ~2.2s (see _AuthNotifier) once auth + profile are known.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // always dispose animation controllers!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Animated Logo ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF9C8FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── App Name ───────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _logoFade,
              builder: (context, child) =>
                  FadeTransition(opacity: _logoFade, child: child),
              child: Text(
                'AI Career Coach',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),

            const SizedBox(height: 8),

            // ── Tagline ────────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _taglineFade,
              builder: (context, child) =>
                  FadeTransition(opacity: _taglineFade, child: child),
              child: Text(
                'Your personal career growth partner',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            const SizedBox(height: 80),

            // ── Loading indicator ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _taglineFade,
              builder: (context, child) =>
                  FadeTransition(opacity: _taglineFade, child: child),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}