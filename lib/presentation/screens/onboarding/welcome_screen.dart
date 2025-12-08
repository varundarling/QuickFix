import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor = Colors.white;
    final secondaryTextColor = Colors.white.withValues(alpha: 0.9);

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

                    // 👑 Top hero + heading
                    Column(
                      children: [
                        _buildHeroLogo(),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to QuickFix',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'All your home services in one app. Fast, reliable, and hassle-free.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),

                    // 🌟 Simple feature chips
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Here’s what you can do:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _featureChip(
                          context,
                          icon: Icons.flash_on,
                          title: 'Book in seconds',
                          subtitle: 'Choose a service and time that suits you.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _featureChip(
                          context,
                          icon: Icons.verified_user,
                          title: 'Trusted professionals',
                          subtitle: 'See ratings and reviews before booking.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _featureChip(
                          context,
                          icon: Icons.home_repair_service_outlined,
                          title: 'Everything in one place',
                          subtitle: 'Repairs, cleaning, maintenance & more.',
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40), // space above bottom nav
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 🧩 Hero with BIG APP LOGO inside a glowing circle
  Widget _buildHeroLogo() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow circle
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipOval(
                child: Image.asset(
                  // 🔴 Replace with your real asset path
                  'assets/logo/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icon so app doesn't crash if asset missing in dev
                    return const Icon(
                      Icons.home_repair_service_outlined,
                      size: 60,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 Simple, clean feature chip
  Widget _featureChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.primary.withValues(alpha: 0.12);
    final mainTextColor = isDark
        ? Colors.white
        : Colors.black.withValues(alpha: 0.85);
    final subTextColor = mainTextColor.withValues(alpha: 0.9);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
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
                    color: mainTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subTextColor,
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
