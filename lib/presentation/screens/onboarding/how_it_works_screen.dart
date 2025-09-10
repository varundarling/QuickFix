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
  late List<AnimationController> _stepControllers;
  late List<Animation<double>> _stepAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // ✅ UPDATED: Now 4 controllers for 4 cards (Login + 3 original)
    _stepControllers = List.generate(
      4, // ✅ CHANGED: from 3 to 4
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _stepAnimations = _stepControllers
        .map(
          (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
          ),
        )
        .toList();

    _startAnimations();
  }

  void _startAnimations() {
    if (mounted) {
      _controller.forward();
      _animateSteps();
    }
  }

  void _animateSteps() async {
    // ✅ UPDATED: Now animates 4 cards
    for (int i = 0; i < _stepControllers.length; i++) {
      await Future.delayed(Duration(milliseconds: 200 + i * 300));

      if (mounted) {
        _stepControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, Color(0xFF3B82F6), Colors.white],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _safeOpacity(_controller.value),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight - 120),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Title
                          const Text(
                            'How QuickFix Works',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Simple steps to get things done',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Steps
                          Column(
                            children: [
                              // ✅ NEW: STEP 1 - LOGIN CARD
                              AnimatedBuilder(
                                animation: _stepAnimations[0],
                                builder: (context, child) => Transform.scale(
                                  scale: _safeOpacity(_stepAnimations[0].value),
                                  child: _buildStep(
                                    1,
                                    Icons.login,
                                    'Login',
                                    'Sign in to access trusted professionals and book services',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ✅ STEP 2 - BROWSE & SELECT CARD (was step 1)
                              AnimatedBuilder(
                                animation: _stepAnimations[1],
                                builder: (context, child) => Transform.scale(
                                  scale: _safeOpacity(_stepAnimations[1].value),
                                  child: _buildStep(
                                    2, // ✅ CHANGED: from 1 to 2
                                    Icons.search,
                                    'Browse & Select',
                                    'Find the perfect service for your needs from our trusted professionals',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ✅ STEP 3 - BOOK & SCHEDULE CARD (was step 2)
                              AnimatedBuilder(
                                animation: _stepAnimations[2],
                                builder: (context, child) => Transform.scale(
                                  scale: _safeOpacity(_stepAnimations[2].value),
                                  child: _buildStep(
                                    3, // ✅ CHANGED: from 2 to 3
                                    Icons.calendar_today,
                                    'Book & Schedule',
                                    'Choose your preferred date and time that works for you',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ✅ STEP 4 - RELAX & ENJOY CARD (was step 3)
                              AnimatedBuilder(
                                animation: _stepAnimations[3],
                                builder: (context, child) => Transform.scale(
                                  scale: _safeOpacity(_stepAnimations[3].value),
                                  child: _buildStep(
                                    4, // ✅ CHANGED: from 3 to 4
                                    Icons.check_circle,
                                    'Relax & Enjoy',
                                    'Sit back while our professional takes care of everything',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // Bottom message
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'It\'s that simple! Join Now !',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.primary.withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ✅ Regular step (non-clickable)
  Widget _buildStep(
    int number,
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Step number circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary.withOpacity(0.7),
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
