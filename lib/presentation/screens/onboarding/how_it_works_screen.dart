import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final List<AnimationController> _stepControllers;
  late final List<Animation<double>> _stepFade;
  late final List<Animation<Offset>> _stepSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _stepControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      ),
    );
    _stepFade = _stepControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _stepSlide = _stepControllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
        )
        .toList();

    _controller.forward();
    _animateSteps();
  }

  Future<void> _animateSteps() async {
    for (int i = 0; i < _stepControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: 120 + i * 140));
      if (mounted) _stepControllers[i].forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.black.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.97);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
                              'How QuickFix Works',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '4 simple steps from booking to completion.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),

                        Column(
                          children: List.generate(4, (i) {
                            final params = [
                              {
                                'icon': Icons.login,
                                'title': 'Login',
                                'subtitle':
                                    'Create an account or sign in to get started.',
                              },
                              {
                                'icon': Icons.search,
                                'title': 'Browse & select',
                                'subtitle':
                                    'Explore services and choose what you need.',
                              },
                              {
                                'icon': Icons.calendar_today,
                                'title': 'Book & schedule',
                                'subtitle':
                                    'Pick the date and time that works best for you.',
                              },
                              {
                                'icon': Icons.check_circle,
                                'title': 'Relax & get it done',
                                'subtitle':
                                    'Your professional arrives and completes the job.',
                              },
                            ];
                            final item = params[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeTransition(
                                opacity: _stepFade[i],
                                child: SlideTransition(
                                  position: _stepSlide[i],
                                  child: _buildStepCard(
                                    context: context,
                                    number: i + 1,
                                    icon: item['icon'] as IconData,
                                    title: item['title'] as String,
                                    subtitle: item['subtitle'] as String,
                                    cardColor: cardColor,
                                  ),
                                ),
                              ),
                            );
                          }),
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
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.route, size: 52, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required BuildContext context,
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? Colors.white
        : Colors.black.withValues(alpha: 0.85);

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(height: 2),
                Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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
