import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen>
    with TickerProviderStateMixin {
  late AnimationController _shieldController;
  late AnimationController _itemsController;
  late Animation<double> _shieldAnimation;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();

    _shieldController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _itemsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shieldAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shieldController, curve: Curves.elasticOut),
    );

    _itemAnimations = List.generate(4, (index) {
      final double begin = (index * 0.15).clamp(0.0, 0.8);
      final double end = (begin + 0.6).clamp(begin + 0.1, 1.0);

      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _itemsController,
          curve: Interval(begin, end, curve: Curves.easeOutBack),
        ),
      );
    });

    if (mounted) {
      _shieldController.forward();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _itemsController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _shieldController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), AppColors.primary, Color(0xFFF1F5F9)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          // ✅ CRITICAL: Enable scrolling for entire screen
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05, // ✅ RESPONSIVE: 5% of screen width
            vertical: 16, // ✅ REDUCED: from 24 to 16
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  screenHeight -
                  120, // ✅ RESPONSIVE: Minimum height based on screen
            ),
            child: Column(
              children: [
                SizedBox(
                  height: screenHeight * 0.02,
                ), // ✅ RESPONSIVE: 2% of screen height
                // Main shield animation
                AnimatedBuilder(
                  animation: _shieldAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _safeOpacity(_shieldAnimation.value),
                      child: Container(
                        width:
                            screenWidth *
                            0.4, // ✅ RESPONSIVE: 40% of screen width
                        height:
                            screenWidth *
                            0.4, // ✅ RESPONSIVE: Square based on width
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.2,
                          ),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Icon(
                                  Icons.verified_user,
                                  size:
                                      screenWidth *
                                      0.15, // ✅ RESPONSIVE: 15% of screen width
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                            // Security badges
                            Positioned(
                              top: 15,
                              right: 15,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.security,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 15,
                              left: 15,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(
                  height: screenHeight * 0.04,
                ), // ✅ RESPONSIVE: 4% of screen height
                // Title
                const Text(
                  'Your Safety First',
                  style: TextStyle(
                    fontSize: 28, // ✅ REDUCED: from 32 to 28
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(
                  height: screenHeight * 0.015,
                ), // ✅ RESPONSIVE: 1.5% of screen height

                Text(
                  'We ensure every interaction is safe and secure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, // ✅ REDUCED: from 18 to 16
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),

                SizedBox(
                  height: screenHeight * 0.04,
                ), // ✅ RESPONSIVE: 4% of screen height
                // Safety features
                Column(
                  children: [
                    AnimatedBuilder(
                      animation: _itemAnimations[0],
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          50 * (1 - _safeOpacity(_itemAnimations[0].value)),
                          0,
                        ), // ✅ REDUCED: from 100 to 50
                        child: Opacity(
                          opacity: _safeOpacity(_itemAnimations[0].value),
                          child: _buildSafetyItem(
                            Icons.verified,
                            'Identity Verified',
                            'All service providers undergo thorough verification',
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      height: screenHeight * 0.015,
                    ), // ✅ RESPONSIVE: 1.5% of screen height

                    AnimatedBuilder(
                      animation: _itemAnimations[1],
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          -50 * (1 - _safeOpacity(_itemAnimations[1].value)),
                          0,
                        ), // ✅ REDUCED: from -100 to -50
                        child: Opacity(
                          opacity: _safeOpacity(_itemAnimations[1].value),
                          child: _buildSafetyItem(
                            Icons.star_rate,
                            'Rated & Reviewed',
                            'Real reviews from real customers you can trust',
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.015),

                    AnimatedBuilder(
                      animation: _itemAnimations[2],
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          50 * (1 - _safeOpacity(_itemAnimations[2].value)),
                          0,
                        ),
                        child: Opacity(
                          opacity: _safeOpacity(_itemAnimations[2].value),
                          child: _buildSafetyItem(
                            Icons.payment,
                            'Secure Payments',
                            'Your payment information is always protected',
                          ),
                        ),
                      ),
                    ),

                    // SizedBox(height: screenHeight * 0.015),

                    // AnimatedBuilder(
                    //   animation: _itemAnimations[3],
                    //   builder: (context, child) => Transform.translate(
                    //     offset: Offset(
                    //       -50 * (1 - _safeOpacity(_itemAnimations[3].value)),
                    //       0,
                    //     ),
                    //     child: Opacity(
                    //       opacity: _safeOpacity(_itemAnimations[3].value),
                    //       child: _buildSafetyItem(
                    //         Icons.support_agent,
                    //         '24/7 Support',
                    //         'Our team is always here to help when you need us',
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),

                SizedBox(
                  height: screenHeight * 0.04,
                ), // ✅ RESPONSIVE: 4% of screen height
                // Final CTA and trust badge
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ), // ✅ REDUCED: from 18 to 16
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text(
                          'Get Started Now',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
 
                  ],
                ),

                SizedBox(height: screenHeight * 0.02), // ✅ FINAL SPACING
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16), // ✅ REDUCED: from 20 to 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45, // ✅ REDUCED: from 50 to 45
            height: 45, // ✅ REDUCED: from 50 to 45
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22, // ✅ REDUCED: from 24 to 22
            ),
          ),
          const SizedBox(width: 14), // ✅ REDUCED: from 16 to 14
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15, // ✅ REDUCED: from 16 to 15
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 3), // ✅ REDUCED: from 4 to 3
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13, // ✅ REDUCED: from 14 to 13
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      context.go('/user-type-selection');
    }
  }
}
