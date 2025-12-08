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

  final List<Widget> _pages = const [
    WelcomeScreen(),
    CustomerExplanationScreen(),
    ProviderExplanationScreen(),
    HowItWorksScreen(),
    SafetyScreen(),
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      if (context.mounted) {
        context.go('/user-type-selection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 Give a solid background so no black shows behind pages
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // 🔹 Fullscreen PageView behind
          PageView(
            controller: _pageController,
            // 👇 Remove bouncing/overscroll so you can't "pull" to a black page
            physics: const ClampingScrollPhysics(),
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
            },
            children: _pages,
          ),

          // 🔹 Floating bottom controls (Skip, dots, Next, helper text)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row: Skip  •  Dots  •  Next
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Transparent Skip
                        TextButton(
                          onPressed: _finishOnboarding,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            foregroundColor: Colors.white.withValues(alpha: 0.85),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // Dots
                        Row(
                          children: List.generate(
                            _pages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              width: _currentPage == index ? 18 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: _currentPage == index ? 0.9 : 0.45,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        // Semi-transparent "glass" Next/Get started
                        GestureDetector(
                          onTap: () {
                            if (_currentPage == _pages.length - 1) {
                              _finishOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get started'
                                  : 'Next',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Floating helper text
                    Text(
                      'Swipe left or tap Next to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
