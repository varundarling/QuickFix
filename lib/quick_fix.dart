// ignore_for_file: file_names, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/routes/app_router.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/rating_providers.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/favourites_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class QuickFix extends StatefulWidget {
  const QuickFix({super.key});

  @override
  State<QuickFix> createState() => _QuickFixState();
}

class _QuickFixState extends State<QuickFix> with WidgetsBindingObserver {
  bool? _showOnboarding; // ✅ ADD: Track onboarding state
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _checkOnboardingStatus(); // ✅ ADD: Check onboarding status
    _setupAuthenticationListener();
    _setupForegroundMessageListener();
    _setupAppLifecycleHandling();
  }

  // ✅ ADD: Check if user has seen onboarding
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    setState(() {
      _showOnboarding = !hasSeenOnboarding;
      _router = AppRouter.router(showOnboarding: _showOnboarding!);
    });
  }

  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _setupUserNotifications(user);

        // final prefs = await SharedPreferences.getInstance();
        // await prefs.setBool('hasSeenOnboarding', true);

        // Ensure current session hides onboarding instantly
        // if (mounted && _showOnboarding == true) {
        //   setState(() {
        //     _showOnboarding = false;
        //     _router = AppRouter.router(showOnboarding: _showOnboarding!);
        //   });
        // }

        // try {
        //   final ctx = navigatorKey.currentContext;
        //   if (ctx != null) {
        //     // Defer to centralized role-based navigation without defaulting to customer
        //     await NavigationHelper.navigateBasedOnRole(ctx);
        //   }
        // } catch (_) {
        //   // If navigation cannot be determined yet, do nothing; screens will handle
        // }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOnboarding', true);
      }
    });
  }

  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // debugPrint(
      //   '📱 Foreground message received: ${message.notification?.title}',
      // );

      if (message.notification != null && mounted) {
        _showForegroundNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      //debugPrint('📱 App opened from notification: ${message.data}');
      _handleNotificationTap(message);
    });
  }

  void _setupAppLifecycleHandling() {
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        //debugPrint('📱 App opened from terminated state: ${message.data}');
        _handleNotificationTap(message);
      }
    });
  }

  Future<void> _setupUserNotifications(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userType = userDoc.data()?['userType'] as String?;

      if (userType == 'customer') {
        await FirebaseMessaging.instance.subscribeToTopic('customer_updates');
        //debugPrint('✅ Customer notification setup complete');
      } else if (userType == 'provider') {
        await FirebaseMessaging.instance.subscribeToTopic('provider_updates');
        // debugPrint('✅ Provider notification setup complete');
      }

      //debugPrint('✅ User notifications configured for: $userType');
    } catch (e) {
      //debugPrint('❌ Error setting up user notifications: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (message.notification != null && navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? 'Notification',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message.notification!.body != null)
                Text(message.notification!.body!),
            ],
          ),
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => _handleNotificationTap(message),
          ),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    //debugPrint('📱 Handling notification tap: ${message.data}');

    if (message.data.containsKey('screen')) {
      final screen = message.data['screen'];
      navigatorKey.currentState?.pushNamed('/$screen');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      //debugPrint('📱 App resumed');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ MODIFY: Show loading while checking onboarding status
    if (_showOnboarding == null) {
      return MaterialApp(
        title: 'QuickFix',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Initializing...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => RatingProvider()),
      ],
      child: MaterialApp.router(
        title: 'QuickFix',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Poppins',
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.snackbarBackground,
            contentTextStyle: const TextStyle(
              color: AppColors.snackbarText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            actionTextColor: AppColors.snackbarText,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 6,
          ),
        ),
        routerConfig: _router!,
      ),
    );
  }
}
