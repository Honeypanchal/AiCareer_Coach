import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9C8FFF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 16),
          Text('AI Career Coach',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
            'Version 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey),
          ),
          const SizedBox(height: 28),
          Text(
            'A learning project that helps you practice interviews, review your resume, and get career guidance from Gemini — personalized to your target role.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('What’s inside', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          const _Bullet('AI Chat — career coaching with your profile context'),
          const _Bullet('Resume Check — score, prioritised fixes, missing keywords and an improved CV PDF'),
          const _Bullet('Mock Interview — adaptive questions, feedback on every answer and a final report'),
          const _Bullet('Profile — role, skills, theme, account'),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
