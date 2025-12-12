// onboarding_main_screen.dart
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (page < 0 || page >= _pages.length) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

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

  /// Subtle responsive transform while keeping PageView default scroll behavior.
  Widget _buildResponsivePage(int index, Widget child) {
    const double maxTranslateY = 12.0;
    const double minScale = 0.99;

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        if (!_pageController.hasClients) return SizedBox.expand(child: child);
        final double page =
            _pageController.page ?? _pageController.initialPage.toDouble();
        double diff = index - page;
        diff = diff.clamp(-1.0, 1.0);

        final double translateY = diff * maxTranslateY * 0.35;
        final double scale = (1.0 - (diff.abs() * (1.0 - minScale))).clamp(
          minScale,
          1.0,
        );

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: SizedBox.expand(child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paint the gradient once behind all pages so two pages will never have a seam.
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                physics: const PageScrollPhysics(),
                padEnds:
                    false, // removes Flutter's edge padding that can create seams
                clipBehavior: Clip.hardEdge,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  // Each page must be transparent at the top level so the shared gradient shows through
                  return _buildResponsivePage(index, _pages[index]);
                },
              ),

              // Bottom controls: Back • Dots • Next/Get started
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _currentPage == 0 ? 0.0 : 1.0,
                              child: IconButton(
                                onPressed: _currentPage == 0
                                    ? null
                                    : () {
                                        if (_currentPage > 0) {
                                          _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 280,
                                            ),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.arrow_back_ios),
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_pages.length, (index) {
                                final isActive = index == _currentPage;
                                return GestureDetector(
                                  onTap: () => _goTo(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: isActive ? 18 : 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                        isActive ? 0.96 : 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              }),
                            ),

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
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.28),
                                    width: 1.0,
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

                        const SizedBox(height: 8),

                        Text(
                          'Swipe left or tap Next to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.92),
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
        ),
      ),
    );
  }
}
