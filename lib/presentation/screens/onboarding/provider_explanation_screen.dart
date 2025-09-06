import 'package:flutter/material.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class ProviderExplanationScreen extends StatefulWidget {
  const ProviderExplanationScreen({super.key});

  @override
  State<ProviderExplanationScreen> createState() =>
      _ProviderExplanationScreenState();
}

class _ProviderExplanationScreenState extends State<ProviderExplanationScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _moneyController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _moneyController = AnimationController(
      duration: const Duration(seconds: 2),
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

    _startAnimations();
  }

  void _startAnimations() {
    if (mounted) {
      _controller.forward();
      _moneyController.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _moneyController.dispose();
    super.dispose();
  }

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ✅ UPDATED: Blue and white theme for providers
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1E3A8A), // Darker blue
            AppColors.primary,
            Colors.white,
          ],
          stops: [0.0, 0.5, 1.0],
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
                      const SizedBox(height: 10),

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
                            // Main provider icon
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(
                                  Icons.business_center,
                                  size: 60,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                            // Animated money icons
                            AnimatedBuilder(
                              animation: _moneyController,
                              builder: (context, child) {
                                final animValue = _safeOpacity(
                                  _moneyController.value,
                                );
                                return Positioned(
                                  top:
                                      35 +
                                      (10 *
                                          (0.5 +
                                              0.5 *
                                                  Curves.easeInOut.transform(
                                                    animValue,
                                                  ))),
                                  right: 45,
                                  child: Transform.scale(
                                    scale:
                                        0.8 +
                                        0.4 *
                                            Curves.easeInOut.transform(
                                              animValue,
                                            ),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.attach_money,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Growth chart
                            Positioned(
                              bottom: 35,
                              left: 35,
                              child: _buildGrowthChart(),
                            ),

                            // Tools icon
                            Positioned(
                              top: 70,
                              left: 25,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.build,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title and description
                      const Text(
                        'Grow Your Business',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'Join thousands of professionals earning more with QuickFix',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Feature cards
                      _buildFeatureCard(
                        Icons.people,
                        'Find Customers',
                        'Connect with people who need your services',
                      ),

                      const SizedBox(height: 16),

                      _buildFeatureCard(
                        Icons.trending_up,
                        'Increase Revenue',
                        'Get more bookings and grow your income',
                      ),

                      const SizedBox(height: 16),

                      _buildFeatureCard(
                        Icons.schedule,
                        'Flexible Schedule',
                        'Work when you want, where you want',
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

  Widget _buildGrowthChart() {
    return AnimatedBuilder(
      animation: _moneyController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(45, 35),
          painter: GrowthChartPainter(_safeOpacity(_moneyController.value)),
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

class GrowthChartPainter extends CustomPainter {
  final double progress;

  GrowthChartPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.3 * progress, size.height * 0.8);
    path.lineTo(size.width * 0.6 * progress, size.height * 0.4);
    path.lineTo(size.width * progress, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
