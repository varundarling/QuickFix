import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/presentation/screens/auth/login_screen.dart';
import 'package:quickfix/presentation/screens/auth/sign_Up_Screen.dart';
import 'package:quickfix/presentation/screens/auth/user_type_selection_screen.dart';
import 'package:quickfix/presentation/screens/booking/customer_booking_details_screen.dart';
import 'package:quickfix/presentation/screens/booking/customer_booking_screen.dart';
import 'package:quickfix/presentation/screens/home/customer_settings_screen.dart';
import 'package:quickfix/presentation/screens/home/favourites_screen.dart';
import 'package:quickfix/presentation/screens/home/home_screen.dart';
import 'package:quickfix/presentation/screens/onboarding/onboarding_main_screen.dart';
import 'package:quickfix/presentation/screens/profile/profile_screen.dart';
import 'package:quickfix/presentation/screens/profile/provider_profile_screen.dart';
import 'package:quickfix/presentation/screens/provider/analytics_screen.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/screens/provider/create_service_screen.dart';
import 'package:quickfix/presentation/screens/provider/provider_dashboard_screen.dart';
import 'package:quickfix/presentation/screens/provider/provider_settings_screen.dart';
import 'package:quickfix/presentation/screens/splash/splash_screen.dart';
import 'package:quickfix/quick_fix.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reactively refresh GoRouter on auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription _sub;
  GoRouterRefreshStream(Stream stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Resolve and cache user role once per UID
class RoleResolver {
  static Future<String?> getRole(String uid) async {
    // 1) Firestore users/{uid}.userType
    try {
      final fs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final r = fs.data()?['userType']?.toString();
      if (r != null && r.isNotEmpty) {
        await _cache(uid, r);
        return r;
      }
    } catch (_) {}

    // 2) RTDB users/{uid}/public_info/userType
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/$uid/public_info/userType')
          .get();
      if (snap.exists && snap.value != null) {
        final r = snap.value.toString();
        await _cache(uid, r);
        return r;
      }
    } catch (_) {}

    // 3) Local cache fallback (saved during auth bootstrap)
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_type_$uid');
  }

  static Future<void> _cache(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_type_$uid', role);
  }
}

class AppRouter {
  static GoRouter router({required bool showOnboarding}) {
    return GoRouter(
      initialLocation: showOnboarding ? '/onboarding' : '/splash',
      navigatorKey: navigatorKey,
      refreshListenable: GoRouterRefreshStream(
        FirebaseAuth.instance.authStateChanges(),
      ), // reactive
      redirect: (context, state) async {
        final user = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;

        final isOnboardingPath = state.matchedLocation == '/onboarding';
        final isAuthPath =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup' ||
            state.matchedLocation == '/user-type-selection' ||
            isOnboardingPath;

        // Logged out: only allow auth/onboarding; drive splash
        if (!isLoggedIn) {
          if (state.matchedLocation == '/splash') {
            return showOnboarding ? '/onboarding' : '/user-type-selection';
          }
          if (!isAuthPath && state.matchedLocation != '/splash') {
            return showOnboarding ? '/onboarding' : '/user-type-selection';
          }
          return null;
        }

        // Logged in: enforce landing only from splash/onboarding/auth
        final mustLand =
            isAuthPath ||
            state.matchedLocation == '/splash' ||
            state.matchedLocation == '/onboarding';
        if (!mustLand) return null;

        // Resolve role; if not ready, don't misroute
        final role = await RoleResolver.getRole(
          user!.uid,
        ); // implement lookup + cache
        if (role == null) return null;

        final r = role.toLowerCase().replaceAll('_', '');
        final isProvider = r == 'provider' || r == 'serviceprovider';
        return isProvider ? '/provider-dashboard' : '/home';
      },
      routes: [
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingMainScreen(),
        ),

        // Splash Screen
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Authentication Routes
        GoRoute(
          path: '/user-type-selection',
          name: 'user-type-selection',
          builder: (context, state) => const UserTypeSelectionScreen(),
        ),

        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            final userType =
                state.uri.queryParameters['userType'] ?? 'customer';
            return LoginScreen(preselectedUserType: userType);
          },
        ),

        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) {
            final userType =
                state.uri.queryParameters['userType'] ?? 'customer';
            return SignUpScreen(preselectedUserType: userType);
          },
        ),

        // Customer Routes
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),

        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        GoRoute(
          path: '/customer-bookings',
          name: 'customer-bookings',
          builder: (context, state) => const CustomerBookingsScreen(),
        ),

        GoRoute(
          path: '/customer-booking-detail/:bookingId',
          name: 'customer-booking-detail',
          builder: (context, state) {
            final bookingId = state.pathParameters['bookingId']!;
            return CustomerBookingDetailScreen(bookingId: bookingId);
          },
        ),

        // ✅ NEW: Favorites Screen
        GoRoute(
          path: '/favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),

        // Provider Routes
        GoRoute(
          path: '/provider-dashboard',
          name: 'provider-dashboard',
          builder: (context, state) => const ProviderDashboardScreen(),
        ),

        GoRoute(
          path: '/create-service',
          name: 'create-service',
          builder: (context, state) => const CreateServiceScreen(),
        ),

        GoRoute(
          path: '/provider-profile',
          name: 'provider-profile',
          builder: (context, state) => const ProviderProfileScreen(),
        ),

        GoRoute(
          path: '/provider-booking-detail/:bookingId',
          name: 'provider-booking-detail',
          builder: (context, state) {
            final bookingId = state.pathParameters['bookingId']!;
            return BookingDetailForProvider(bookingId: bookingId);
          },
        ),

        // Add this to your GoRouter routes:
        GoRoute(
          path: '/provider-dashboard/:tab',
          name: 'provider-dashboard-tab',
          builder: (context, state) {
            final tabIndex =
                int.tryParse(state.pathParameters['tab'] ?? '0') ?? 0;
            return ProviderDashboardScreen(initialTabIndex: tabIndex);
          },
        ),

        // In app_router.dart - ADD these routes
        GoRoute(
          path: '/payment/:bookingId',
          name: 'payment',
          builder: (context, state) {
            // You'll need to pass the booking object or fetch it
            // For now, returning a placeholder
            return const Scaffold(body: Center(child: Text('Payment Screen')));
          },
        ),

        GoRoute(
          path: '/customer-payment/:bookingId',
          name: 'customer-payment',
          builder: (context, state) {
            // You'll need to pass the booking object or fetch it
            return const Scaffold(
              body: Center(child: Text('Customer Payment Screen')),
            );
          },
        ),

        GoRoute(
          path: '/provider-analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/provider-settings',
          builder: (context, state) => const ProviderSettingsScreen(),
        ),

        GoRoute(
          path: '/customer-settings',
          builder: (context, state) => const CustomerSettingsScreen(),
        ),

        GoRoute(
          path: '/customer-otp/:bookingId',
          name: 'customer-otp',
          builder: (context, state) {
            state.pathParameters['bookingId']!;
            // You'll need to fetch the booking or pass it through extra
            return const Scaffold(
              body: Center(child: Text('Customer OTP Screen')),
            );
          },
        ),

        GoRoute(
          path: '/otp-verification/:bookingId',
          name: 'otp-verification',
          builder: (context, state) {
            state.pathParameters['bookingId']!;
            // You'll need to fetch the booking or pass it through extra
            return const Scaffold(
              body: Center(child: Text('OTP Verification Screen')),
            );
          },
        ),

        GoRoute(
          path: '/service-progress/:bookingId',
          name: 'service-progress',
          builder: (context, state) {
            state.pathParameters['bookingId']!;
            // You'll need to fetch the booking or pass it through extra
            return const Scaffold(
              body: Center(child: Text('Service Progress Screen')),
            );
          },
        ),

        GoRoute(
          path: '/real-time-payment/:bookingId',
          name: 'real-time-payment',
          builder: (context, state) {
            state.pathParameters['bookingId']!;
            // You'll need to fetch the booking or pass it through extra
            return const Scaffold(
              body: Center(child: Text('Real-time Payment Screen')),
            );
          },
        ),
      ],
    );
  }

  static final GoRouter getrouter = router(showOnboarding: false);
}
