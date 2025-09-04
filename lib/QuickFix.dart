import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _setupAuthenticationListener();
    _setupForegroundMessageListener();
    _setupAppLifecycleHandling();
  }

  void _setupAuthenticationListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _setupUserNotifications(user);
      }
    });
  }

  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📱 Foreground message received: ${message.notification?.title}',
      );

      if (message.notification != null && mounted) {
        _showForegroundNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from notification: ${message.data}');
      _handleNotificationTap(message);
    });
  }

  void _setupAppLifecycleHandling() {
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        debugPrint('📱 App opened from terminated state: ${message.data}');
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
        debugPrint('✅ Customer notification setup complete');
      } else if (userType == 'provider') {
        await FirebaseMessaging.instance.subscribeToTopic('provider_updates');
        debugPrint('✅ Provider notification setup complete');
      }

      debugPrint('✅ User notifications configured for: $userType');
    } catch (e) {
      debugPrint('❌ Error setting up user notifications: $e');
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
    debugPrint('📱 Handling notification tap: ${message.data}');

    if (message.data.containsKey('screen')) {
      String screen = message.data['screen'];
      // Navigate to specific screen based on data
      // AppRouter.navigateTo(navigatorKey.currentContext!, screen);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed');
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => RatingProvider()), // ✅ ADD THIS LINE
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
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
