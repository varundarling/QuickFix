import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _logoController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _buttonAnimation;
  String? _selectedUserType;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🏗️ UserTypeSelection initState - _selectedUserType: $_selectedUserType',
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // ✅ NEW: Button pulse animation controller
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _logoAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // ✅ NEW: Button glow animation
    _buttonAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _logoController.repeat(reverse: true);
    _buttonController.repeat(reverse: true); // ✅ NEW: Start button animation
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    _buttonController.dispose(); // ✅ NEW: Dispose button controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, Color(0xFF4A90E2), Color(0xFFF8FAFC)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCompactHeader(),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        _buildDetailedCard(
                          title: 'I Need Services',
                          subtitle:
                              'Book trusted professionals for your home services',
                          icon: Icons.home_repair_service_outlined,
                          userType: 'customer',
                          color: const Color(0xFF3B82F6),
                          features: [
                            'Browse 500+ services',
                            'Verified professionals',
                            'Real-time tracking',
                            'Secure payments',
                          ],
                        ),

                        const SizedBox(height: 16),

                        _buildDetailedCard(
                          title: 'I Provide Services',
                          subtitle: 'Grow your business with new opportunities',
                          icon: Icons.business_center_outlined,
                          userType: 'provider',
                          color: const Color(0xFF10B981),
                          features: [
                            'Expand your reach',
                            'Flexible scheduling',
                            'Instant payments',
                            'Professional tools',
                          ],
                        ),

                        const SizedBox(height: 32),

                        // ✅ ENHANCED: Super attractive buttons
                        _buildEnhancedButtons(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _logoAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _logoAnimation.value,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFF8FAFC)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.build_circle,
                          size: 26,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFF1F5F9)],
                  ).createShader(bounds),
                  child: Text(
                    'Welcome to ${AppStrings.appName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your path to success',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String userType,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedUserType == userType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserType = userType;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [Colors.white, const Color(0xFFFAFBFF), Colors.white]
                : [
                    Colors.white.withOpacity(0.9),
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.9),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 25 : 12,
              offset: Offset(0, isSelected ? 12 : 6),
              spreadRadius: isSelected ? 1 : 0,
            ),
            if (isSelected)
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [color.withOpacity(0.2), color.withOpacity(0.1)]
                            : [
                                Colors.grey.withOpacity(0.1),
                                Colors.grey.withOpacity(0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        icon,
                        key: ValueKey('${userType}_$isSelected'),
                        size: 32,
                        color: isSelected ? color : Colors.grey[600],
                      ),
                    ),
                  ),

                  const Spacer(),

                  AnimatedScale(
                    scale: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isSelected ? 24 : 22,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : Colors.grey[800],
                  letterSpacing: 0.3,
                ),
                child: Text(title),
              ),

              const SizedBox(height: 8),

              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isSelected
                          ? color.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    curve: Curves.easeOutBack,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: isSelected ? color : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            features[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? color.withOpacity(0.9)
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ SUPER ENHANCED: Attractive and clearly visible buttons
  Widget _buildEnhancedButtons() {
    return AnimatedBuilder(
      animation: _buttonAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              children: [
                // ✅ ENHANCED SIGN UP BUTTON
                Expanded(
                  child: _buildAnimatedButton(
                    isEnabled: _selectedUserType != null,
                    onPressed: _selectedUserType != null
                        ? _continueToSignup
                        : null,
                    child: Container(
                      height: 60, // ✅ LARGER HEIGHT
                      decoration: BoxDecoration(
                        gradient: _selectedUserType != null
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  const Color(0xFF4A90E2),
                                  AppColors.primary,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.withOpacity(0.6),
                                  Colors.grey.withOpacity(0.4),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedUserType != null
                            ? [
                                // ✅ ENHANCED GLOW EFFECT
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(
                                    0.4 * _buttonAnimation.value,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(
                                    0.2 * _buttonAnimation.value,
                                  ),
                                  blurRadius: 30,
                                  offset: const Offset(0, 0),
                                  spreadRadius: 5,
                                ),
                                const BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 8,
                                  offset: Offset(0, -2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _selectedUserType != null
                            ? _continueToSignup
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              color: _selectedUserType != null
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              size: 22, // ✅ LARGER ICON
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 18, // ✅ LARGER FONT
                                fontWeight: FontWeight.w800, // ✅ BOLDER WEIGHT
                                color: _selectedUserType != null
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ✅ ENHANCED LOGIN BUTTON
                Expanded(
                  child: _buildAnimatedButton(
                    isEnabled: _selectedUserType != null,
                    onPressed: _selectedUserType != null
                        ? _continueToLogin
                        : null,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        // ✅ FIXED: Solid background instead of transparent
                        gradient: _selectedUserType != null
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF1E40AF), // Deep blue
                                  Color(0xFF3B82F6), // Medium blue
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.withOpacity(0.4),
                                  Colors.grey.withOpacity(0.2),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedUserType != null
                              ? Colors.white.withOpacity(0.8)
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: _selectedUserType != null
                            ? [
                                // ✅ ENHANCED: Better shadow for visibility
                                BoxShadow(
                                  color: const Color(
                                    0xFF1E40AF,
                                  ).withOpacity(0.4 * _buttonAnimation.value),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.2 * _buttonAnimation.value),
                                  blurRadius: 25,
                                  offset: const Offset(0, 0),
                                  spreadRadius: 3,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: OutlinedButton(
                        onPressed: _selectedUserType != null
                            ? _continueToLogin
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide
                              .none, // Remove default border since we have custom border
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login_outlined,
                              color: _selectedUserType != null
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _selectedUserType != null
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ✅ CUSTOM ANIMATED BUTTON WRAPPER
  Widget _buildAnimatedButton({
    required bool isEnabled,
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _scaleDown() : null,
      onTapUp: isEnabled ? (_) => _scaleUp() : null,
      onTapCancel: isEnabled ? () => _scaleUp() : null,
      child: AnimatedScale(
        scale: isEnabled ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
    );
  }

  void _scaleDown() {
    // Add subtle scale down effect on press
  }

  void _scaleUp() {
    // Return to normal scale
  }

  void _continueToSignup({String? defaultType}) {
    final userType = _selectedUserType ?? defaultType ?? 'customer';
    debugPrint('🚀 Navigating to signup with userType: $userType');
    context.go('/signup?userType=$userType');
  }

  void _continueToLogin({String? defaultType}) {
    final userType = _selectedUserType ?? defaultType ?? 'customer';
    debugPrint('🔑 Navigating to login with userType: $userType');
    context.go('/login?userType=$userType');
  }
}
