import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class InterviewScreen extends StatelessWidget {
  const InterviewScreen({super.key});

  static const _topics = [
    {'label': 'Flutter', 'icon': Icons.phone_android_rounded, 'color': 0xFF6C63FF},
    {'label': 'React', 'icon': Icons.web_rounded, 'color': 0xFF61DAFB},
    {'label': 'Python', 'icon': Icons.code_rounded, 'color': 0xFF3776AB},
    {'label': 'DSA', 'icon': Icons.account_tree_rounded, 'color': 0xFF4CAF82},
    {'label': 'Java', 'icon': Icons.coffee_rounded, 'color': 0xFFFF6B35},
    {'label': 'HR Round', 'icon': Icons.people_outline_rounded, 'color': 0xFFFF5C7D},
    {'label': 'System Design', 'icon': Icons.architecture_rounded, 'color': 0xFFFFB347},
    {'label': 'SQL', 'icon': Icons.storage_rounded, 'color': 0xFF00BCD4},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Mock Interview', style: theme.textTheme.displayMedium),
              const SizedBox(height: 6),
              Text('Pick a topic and practice with AI',
                  style: theme.textTheme.bodyMedium),

              const SizedBox(height: 24),

              // ── Stats row ────────────────────────────────────────────────
              Row(children: [
                _StatCard(label: 'Sessions', value: '0', isDark: isDark),
                const SizedBox(width: 12),
                _StatCard(label: 'Avg Score', value: '--', isDark: isDark),
                const SizedBox(width: 12),
                _StatCard(label: 'Best Topic', value: '--', isDark: isDark),
              ]),

              const SizedBox(height: 28),
              Text('Choose Topic', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // ── Topic grid ───────────────────────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: _topics.length,
                itemBuilder: (context, i) {
                  final topic = _topics[i];
                  final color = Color(topic['color'] as int);
                  return GestureDetector(
                    onTap: () => _showComingSoon(context, topic['label'] as String),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2A40)
                              : const Color(0xFFEEEEF9),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(topic['icon'] as IconData,
                                color: color, size: 20),
                          ),
                          Text(
                            topic['label'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),
              Text('Recent Sessions', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              // ── Empty state ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2A40)
                        : const Color(0xFFEEEEF9),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded,
                        color: AppColors.textGrey.withOpacity(0.5), size: 40),
                    const SizedBox(height: 12),
                    const Text('No sessions yet',
                        style: TextStyle(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Start a mock interview above',
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 13)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String topic) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$topic interview coming in Step 5! 🚀'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatCard(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
            isDark ? const Color(0xFF2A2A40) : const Color(0xFFEEEEF9),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}