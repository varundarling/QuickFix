// ignore_for_file: file_names, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/presentation/providers/rating_providers.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/presentation/providers/favourites_provider.dart';
import 'package:quickfix/core/routes/app_router.dart';
import 'package:go_router/go_router.dart';

// App states - keeping your existing enum
enum AppState { splash, onboarding, auth, customerHome, providerDashboard }

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class QuickFix extends StatefulWidget {
  const QuickFix({super.key});

  @override
  State<QuickFix> createState() => _QuickFixState();
}

class _QuickFixState extends State<QuickFix>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ✅ Current state management
  AppState? _currentState;
  String? _userType;

  // Animation variables
  AnimationController? _transitionController;
  Animation<double>? _transitionAnimation;

  // GoRouter instance
  late GoRouter _goRouter = AppRouter.router(showOnboarding: false);

  // Provider instances
  late AuthProvider _authProvider;
  late ServiceProvider _serviceProvider;
  late BookingProvider _bookingProvider;
  late FavoritesProvider _favoritesProvider;
  late RatingProvider _ratingProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animation safely
    try {
      _transitionController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _transitionAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _transitionController!,
          curve: Curves.easeInOut,
        ),
      );
    } catch (e) {
      debugPrint('❌ Animation initialization failed: $e');
    }

    // Initialize providers
    _authProvider = AuthProvider();
    _serviceProvider = ServiceProvider();
    _bookingProvider = BookingProvider();
    _favoritesProvider = FavoritesProvider();
    _ratingProvider = RatingProvider();

    // Determine initial state (will override _goRouter properly)
    _determineInitialState();
  }

  /// ✅ Determine initial state with proper flow
  Future<void> _determineInitialState() async {
    try {
      // Check onboarding status
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      _goRouter = AppRouter.router(showOnboarding: !hasSeenOnboarding);

      if (!hasSeenOnboarding) {
        // New user - show onboarding with custom flow
        if (mounted) {
          setState(() {
            _currentState = AppState.onboarding;
          });
        }
        return;
      }

      // Check authentication
      await FirebaseAuth.instance.authStateChanges().first;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // Not logged in - use GoRouter for auth
        if (mounted) {
          setState(() {
            _currentState = AppState.auth;
          });
        }
        return;
      }

      // Logged in user - show splash and load data
      if (mounted) {
        setState(() {
          _currentState = AppState.splash;
        });
      }

      await _initializeForLoggedInUser();
    } catch (e) {
      debugPrint('❌ Error determining initial state: $e');
      if (mounted) {
        setState(() {
          _currentState = AppState.auth;
        });
      }
    }
  }

  /// ✅ Initialize for logged-in users with detailed splash updates
  Future<void> _initializeForLoggedInUser() async {
    try {
      // Step 1: Setup
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 2: Configure services
      await Future.delayed(const Duration(milliseconds: 600));
      _setupAuthenticationListener();
      _setupForegroundMessageListener();
      _setupAppLifecycleHandling();

      // Step 3: Load profile
      await Future.delayed(const Duration(milliseconds: 600));
      await _authProvider.ensureUserAuthenticated();
      _userType = await _authProvider.getUserType();

      // Step 4: Load data based on user type
      if (_userType?.toLowerCase() == 'provider') {
        await Future.delayed(const Duration(milliseconds: 600));
        await _preloadProviderData(FirebaseAuth.instance.currentUser!.uid);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        await _preloadCustomerData();
      }

      // Step 5: Final preparation
      await Future.delayed(const Duration(milliseconds: 800));

      // Transition to main screen
      AppState nextState;
      if (_userType?.toLowerCase() == 'provider') {
        nextState = AppState.providerDashboard;
      } else {
        nextState = AppState.customerHome;
      }

      await _transitionToState(nextState);
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      await _transitionToState(AppState.auth);
    }
  }

  /// ✅ Transition between states
  Future<void> _transitionToState(AppState newState) async {
    if (_transitionController != null && _transitionAnimation != null) {
      try {
        // Fade out
        _transitionAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _transitionController!,
            curve: Curves.easeOut,
          ),
        );
        await _transitionController!.forward();

        // Update state
        if (mounted) {
          setState(() {
            _currentState = newState;
          });
        }

        // Fade in
        _transitionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _transitionController!, curve: Curves.easeIn),
        );
        _transitionController!.reset();
        await _transitionController!.forward();
      } catch (e) {
        debugPrint('❌ Animation error: $e');
        if (mounted) {
          setState(() {
            _currentState = newState;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentState = newState;
        });
      }
    }
  }

  // ✅ Handle auth success from GoRouter
  void onAuthSuccess(String userType) {
    if (userType.toLowerCase() == 'provider') {
      _transitionToState(AppState.providerDashboard);
    } else {
      _transitionToState(AppState.customerHome);
    }
  }

  /// ✅ Preload provider data
  Future<void> _preloadProviderData(String providerId) async {
    try {
      await _serviceProvider.loadMyServices();
      await _bookingProvider.loadProviderBookingsWithCustomerData(providerId);
    } catch (e) {
      debugPrint('❌ Provider data preload error: $e');
    }
  }

  /// ✅ Preload customer data
  Future<void> _preloadCustomerData() async {
    try {
      LocationData? location;
      try {
        location = await LocationService.instance.getCurrentLocation();
      } catch (e) {
        debugPrint('⚠️ Location unavailable: $e');
      }

      if (location != null) {
        await _serviceProvider.loadAllServices(
          userLat: location.latitude!,
          userLng: location.longitude!,
        );
      } else {
        await _serviceProvider.loadAllServices();
      }

      await _favoritesProvider.loadFavorites();
      _favoritesProvider.updateFavoriteServices(_serviceProvider.services);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _bookingProvider.loadUserBookingsWithProviderData(
          currentUser.uid,
        );
      }
    } catch (e) {
      debugPrint('❌ Customer data preload error: $e');
    }
  }

  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null &&
          _currentState != AppState.splash &&
          _currentState != AppState.onboarding) {
        await _setupUserNotifications(user);
      }
    });
  }

  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showForegroundNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  void _setupAppLifecycleHandling() {
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
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
      } else if (userType == 'provider') {
        await FirebaseMessaging.instance.subscribeToTopic('provider_updates');
      }
    } catch (e) {
      debugPrint('❌ Notification setup error: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    if (message.notification != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? 'Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message.notification!.body != null)
                Text(message.notification!.body!),
            ],
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () => _handleNotificationTap(message),
          ),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📱 Handling notification tap: ${message.data}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transitionController?.dispose();
    NotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _bookingProvider),
        ChangeNotifierProvider.value(value: _serviceProvider),
        ChangeNotifierProvider.value(value: _favoritesProvider),
        ChangeNotifierProvider.value(value: _ratingProvider),
      ],
      child: MaterialApp.router(
        title: 'QuickFix',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _goRouter,
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }
}
