import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';
import 'package:quickfix/presentation/widgets/buttons/primary_button.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🏗️ UserTypeSelection build - _selectedUserType: $_selectedUserType',
    );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ✅ Updated Logo and Text Layout - Larger logo, smaller text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ✅ Larger App Logo (120x120)
                      Container(
                        width: 120, // ✅ Increased from 80
                        height: 120, // ✅ Increased from 80
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.build_circle,
                                size: 60, // ✅ Increased icon size
                                color: AppColors.primary,
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 16), // ✅ Slightly reduced spacing
                      // ✅ Text with smaller font sizes and 2-line support
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Welcome to ${AppStrings.appName}!',
                              style: const TextStyle(
                                fontSize: 22, // ✅ Decreased from 28
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height:
                                    1.2, // ✅ Line height for better readability
                              ),
                              maxLines: 2, // ✅ Allow up to 2 lines
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose how you want to use QuickFix',
                              style: TextStyle(
                                fontSize: 14, // ✅ Decreased from 16
                                color: Colors.white70,
                                height: 1.3, // ✅ Line height for readability
                              ),
                              maxLines: 2, // ✅ Allow up to 2 lines
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // User Type Selection Cards (unchanged)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildUserTypeOption(
                            title: 'I need services',
                            subtitle:
                                'Book trusted professionals for home services',
                            icon: Icons.person_outline,
                            userType: 'customer',
                            features: [
                              'Browse and book services',
                              'Track service progress',
                              'Rate and review providers',
                            ],
                          ),

                          const SizedBox(height: 20),

                          _buildUserTypeOption(
                            title: 'I provide services',
                            subtitle: 'Grow your business by offering services',
                            icon: Icons.business_center_outlined,
                            userType: 'provider',
                            features: [
                              'List your services',
                              'Manage bookings',
                              'Earn money',
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Side by Side Layout
                          Row(
                            children: [
                              // Continue Button
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _selectedUserType != null
                                      ? 1.0
                                      : 0.5,
                                  duration: const Duration(milliseconds: 300),
                                  child: PrimaryButton(
                                    onPressed: _selectedUserType != null
                                        ? _continueToSignup
                                        : null,
                                    text: 'Sign Up',
                                    backgroundColor: Colors.white,
                                    textColor: AppColors.primary,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Login Button
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _selectedUserType != null
                                      ? 1.0
                                      : 0.5,
                                  duration: const Duration(milliseconds: 300),
                                  child: OutlinedButton(
                                    onPressed: _selectedUserType != null
                                        ? _continueToLogin
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Login'),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Skip Button
                          TextButton(
                            onPressed: () =>
                                _continueToSignup(defaultType: 'customer'),
                            child: const Text(
                              'Skip for now',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String userType,
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
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: isSelected ? AppColors.primary : Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey[800],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 16),

              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _continueToSignup({String? defaultType}) {
    // ✅ Use selected type OR default to 'customer'
    final userType = _selectedUserType ?? defaultType ?? 'customer';
    debugPrint('🚀 Navigating to signup with userType: $userType');

    context.go('/signup?userType=$userType');
  }

  void _continueToLogin({String? defaultType}) {
    // ✅ Use selected type OR default to 'customer'
    final userType = _selectedUserType ?? defaultType ?? 'customer';
    debugPrint('🔑 Navigating to login with userType: $userType');

    context.go('/login?userType=$userType');
  }
}
