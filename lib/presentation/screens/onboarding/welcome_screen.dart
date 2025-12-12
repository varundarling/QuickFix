import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = Colors.white;
    final secondaryTextColor = Colors.white.withOpacity(0.9);

    // Transparent top-level so shared gradient shows through.
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroSize = min(constraints.maxWidth * 0.45, 180.0);
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 12),

                    Column(
                      children: [
                        _buildHeroLogo(heroSize),
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

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Here’s what you can do:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor.withOpacity(0.95),
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroLogo(double size) {
    return SizedBox(
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.95,
            height: size * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
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

  Widget _featureChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final bgColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.96);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : AppColors.primary.withOpacity(0.12);
    final mainTextColor = isDark
        ? Colors.white
        : Colors.black.withOpacity(0.85);
    final subTextColor = mainTextColor.withOpacity(0.9);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
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
