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
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ UPDATED: Blue and white theme
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFF4A90E2), // Lighter blue
            Colors.white,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _safeOpacity(_fadeAnimation.value),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // const Spacer(),
                      const SizedBox(height: 10,),

                      // Hero illustration
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(110),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Main customer icon
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 60,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                            // Floating service icons
                            Positioned(
                              top: 25,
                              right: 35,
                              child: _buildFloatingIcon(
                                Icons.cleaning_services,
                                0.0,
                              ),
                            ),
                            Positioned(
                              bottom: 35,
                              left: 25,
                              child: _buildFloatingIcon(
                                Icons.electrical_services,
                                0.2,
                              ),
                            ),
                            Positioned(
                              top: 60,
                              left: 20,
                              child: _buildFloatingIcon(Icons.plumbing, 0.4),
                            ),
                            Positioned(
                              bottom: 25,
                              right: 20,
                              child: _buildFloatingIcon(Icons.carpenter, 0.6),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Title and description
                      const Text(
                        'Need Home Services?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Book trusted professionals for all your home service needs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Feature cards
                      _buildFeatureCard(
                        Icons.search,
                        'Browse Services',
                        'Find the perfect service for your needs',
                      ),

                      const SizedBox(height: 16),

                      _buildFeatureCard(
                        Icons.calendar_today,
                        'Book Instantly',
                        'Schedule services at your convenience',
                      ),

                      const SizedBox(height: 16),

                      _buildFeatureCard(
                        Icons.verified_user,
                        'Trusted Professionals',
                        'All providers are verified and rated',
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, double delay) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: (1000 + delay * 200).round()),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: _safeOpacity(value),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary.withOpacity(0.7),
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
