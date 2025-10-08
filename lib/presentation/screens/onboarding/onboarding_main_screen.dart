// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/screens/onboarding/welcome_screen.dart';
import 'package:quickfix/presentation/screens/onboarding/customer_explanation_screen.dart';
import 'package:quickfix/presentation/screens/onboarding/provider_explanation_screen.dart';
import 'package:quickfix/presentation/screens/onboarding/how_it_works_screen.dart';
import 'package:quickfix/presentation/screens/onboarding/safety_screen.dart';

class OnboardingMainScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingMainScreen({super.key, this.onComplete});

  @override
  State<OnboardingMainScreen> createState() => _OnboardingMainScreenState();
}

class _OnboardingMainScreenState extends State<OnboardingMainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Widget> _pages = [
    const WelcomeScreen(),
    const CustomerExplanationScreen(),
    const ProviderExplanationScreen(),
    const HowItWorksScreen(),
    const SafetyScreen(),
  ];

  Future<void> _finishOnboarding() async {
    // Mark onboarding as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    // Navigate to your existing UserTypeSelectionScreen
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      // Fallback navigation if no callback provided
      if (context.mounted) {
        context.go('/user-type-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with QuickFix branding
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),

          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: _pages,
          ),

          // Navigation controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: _buildBottomNavigation(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button
          TextButton(
            onPressed: () => _finishOnboarding(),
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Page indicators
          Row(
            children: List.generate(
              _pages.length,
              (index) => Container(
                width: _currentPage == index ? 12 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Next/Done button
          ElevatedButton(
            onPressed: () {
              if (_currentPage == _pages.length - 1) {
                _finishOnboarding();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
