import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.black.withOpacity(0.75)
        : Colors.white.withOpacity(0.97);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroSize = min(constraints.maxWidth * 0.4, 160.0);
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildHero(heroSize),
                            const SizedBox(height: 20),
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
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),

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
        ),
      ),
    );
  }

  Widget _buildHero(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 56,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _safetyCard({
    required BuildContext context,
    required Color cardColor,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black.withOpacity(0.85);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
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
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.95),
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
