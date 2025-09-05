import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/constants/app_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    debugPrint('🔍 Initializing app and checking auth state...');

    final authProvider = context.read<AuthProvider>();

    // ✅ CRITICAL: Wait for Firebase auth to settle
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn =
        authProvider.isAuthenticated && authProvider.user != null;

    if (isLoggedIn) {
      debugPrint('✅ User is logged in: ${authProvider.user!.email}');

      // ✅ CRITICAL: Wait for user session to be fully initialized
      debugPrint('⏳ Waiting for user session initialization...');

      int waitCount = 0;
      while (!authProvider.isInitialized && waitCount < 40) {
        // Max 20 seconds
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;

        if (waitCount % 4 == 0) {
          // Log every 2 seconds
          debugPrint(
            '⏳ Still waiting for initialization... (${waitCount * 0.5}s)',
          );
        }
      }

      if (!authProvider.isInitialized) {
        debugPrint('⚠️ Initialization timeout, proceeding with fallback');
      }

      // ✅ Get user type after initialization
      final userType = await authProvider.getUserType();
      debugPrint('👤 User type determined: $userType');

      // ✅ Verify profile is loaded before navigation
      final hasProfile = authProvider.userModel != null;
      debugPrint('📄 Profile loaded: $hasProfile');

      if (!mounted) return;

      // Navigate based on user type
      if (userType == 'provider') {
        debugPrint('🏢 Navigating to provider dashboard');
        context.go('/provider-dashboard');
      } else {
        debugPrint('🏠 Navigating to customer home');
        context.go('/home');
      }
    } else {
      debugPrint('❌ User not logged in, navigating to user type selection');
      if (mounted) {
        context.go('/user-type-selection');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //App logo
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _buildLogo(),
                ),
                const SizedBox(height: 30),

                //App name
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                //Tagline
                const Text(
                  AppStrings.tagline,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),

                const SizedBox(height: 50),

                //loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Loading user data...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/logo/logo',
      width: 200,
      height: 200,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Failed to load logo: $error');
        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.build_circle,
            size: 120,
            color: AppColors.primary,
          ),
        );
      },
    );
  }
}
