import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class CustomerExplanationScreen extends StatefulWidget {
  const CustomerExplanationScreen({super.key});

  @override
  State<CustomerExplanationScreen> createState() =>
      _CustomerExplanationScreenState();
}

class _CustomerExplanationScreenState extends State<CustomerExplanationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _safe(double v) => v.clamp(0.0, 1.0);

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
                        const SizedBox(height: 6),
                        Column(
                          children: [
                            _buildHero(heroSize),
                            const SizedBox(height: 20),
                            const Text(
                              'Need help at home?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find electricians, plumbers, cleaners and more – all in one place.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),

                        Column(
                          children: [
                            _buildServiceCard(
                              context: context,
                              cardColor: cardColor,
                              icon: Icons.search,
                              title: 'Browse services',
                              subtitle:
                                  'Choose the right service for your home.',
                            ),
                            const SizedBox(height: 12),
                            _buildServiceCard(
                              context: context,
                              cardColor: cardColor,
                              icon: Icons.calendar_today,
                              title: 'Book in seconds',
                              subtitle:
                                  'Pick a date and time that works for you.',
                            ),
                            const SizedBox(height: 12),
                            _buildServiceCard(
                              context: context,
                              cardColor: cardColor,
                              icon: Icons.verified_user,
                              title: 'Trust your provider',
                              subtitle:
                                  'See ratings and reviews before you book.',
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 56,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
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
