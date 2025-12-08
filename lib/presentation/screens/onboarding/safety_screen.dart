import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.black.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.97);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 12),

                    // ⭐ NEW – Circular hero like other screens
                    Column(
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                size: 48,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'Your safety matters',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'We take multiple steps to keep every booking safe and transparent.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),

                    // Safety Points (Cards)
                    Column(
                      children: [
                        _safetyCard(
                          context: context,
                          cardColor: cardColor,
                          icon: Icons.verified_user,
                          title: 'Verified professionals',
                          subtitle:
                              'Every provider is verified before joining QuickFix.',
                        ),
                        const SizedBox(height: 12),

                        _safetyCard(
                          context: context,
                          cardColor: cardColor,
                          icon: Icons.star_rate_rounded,
                          title: 'Ratings & reviews',
                          subtitle:
                              'See what other customers say before you book.',
                        ),
                        const SizedBox(height: 12),

                        _safetyCard(
                          context: context,
                          cardColor: cardColor,
                          icon: Icons.payments,
                          title: 'Transparent payments',
                          subtitle:
                              'Know the charges upfront before confirming a booking.',
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 🔹 Safety card builder
  Widget _safetyCard({
    required BuildContext context,
    required Color cardColor,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Colors.black.withValues(alpha: 0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.95),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
