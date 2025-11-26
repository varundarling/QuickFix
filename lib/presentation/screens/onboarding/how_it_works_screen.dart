import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key});

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  late List<AnimationController> _stepControllers;
  late List<Animation<double>> _stepAnimations;

  @override
  void initState() {
    super.initState();

    // Main fade+slide like ProviderExplanationScreen
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Step card animations
    _stepControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _stepAnimations = _stepControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutBack))
        .toList();

    _controller.forward();
    _animateSteps();
  }

  Future<void> _animateSteps() async {
    for (int i = 0; i < _stepControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 220));
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

  double _safe(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.black.withOpacity(0.75)
        : Colors.white.withOpacity(0.97);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Opacity(
              opacity: _safe(_controller.value),
              child: SlideTransition(
                position: _slideAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 6),

                            // 🔹 Hero + title + subtitle (same structure as Provider screen)
                            Column(
                              children: [
                                _buildHero(),
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
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),

                            // 🔹 Steps as separate cards (layout matches Provider screen)
                            Column(
                              children: [
                                _buildStepCard(
                                  context: context,
                                  index: 0,
                                  number: 1,
                                  icon: Icons.login,
                                  title: 'Login',
                                  subtitle:
                                      'Create an account or sign in to get started.',
                                  cardColor: cardColor,
                                ),
                                const SizedBox(height: 12),
                                _buildStepCard(
                                  context: context,
                                  index: 1,
                                  number: 2,
                                  icon: Icons.search,
                                  title: 'Browse & select',
                                  subtitle:
                                      'Explore services and choose what you need.',
                                  cardColor: cardColor,
                                ),
                                const SizedBox(height: 12),
                                _buildStepCard(
                                  context: context,
                                  index: 2,
                                  number: 3,
                                  icon: Icons.calendar_today,
                                  title: 'Book & schedule',
                                  subtitle:
                                      'Pick the date and time that works best for you.',
                                  cardColor: cardColor,
                                ),
                                const SizedBox(height: 12),
                                _buildStepCard(
                                  context: context,
                                  index: 3,
                                  number: 4,
                                  icon: Icons.check_circle,
                                  title: 'Relax & get it done',
                                  subtitle:
                                      'Your professional arrives and completes the job.',
                                  cardColor: cardColor,
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
          },
        ),
      ),
    );
  }

  // 🔹 Hero icon like other screens (150x150)
  Widget _buildHero() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(110),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.18),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.route, // represents steps/journey
            size: 56,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // 🔹 Step card – same layout style as Provider service cards
  Widget _buildStepCard({
    required BuildContext context,
    required int index,
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black.withOpacity(0.85);

    return AnimatedBuilder(
      animation: _stepAnimations[index],
      builder: (_, __) {
        final v = _stepAnimations[index].value;
        return Transform.scale(
          scale: v,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step icon + number (similar size to provider)
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

                // Text content
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
          ),
        );
      },
    );
  }
}
