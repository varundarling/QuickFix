// lib/core/router/app_router.dart (Updated)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/presentation/screens/auth/login_screen.dart';
import 'package:quickfix/presentation/screens/auth/sign_Up_Screen.dart';
import 'package:quickfix/presentation/screens/auth/user_type_selection_screen.dart';
import 'package:quickfix/presentation/screens/booking/booking_details_screen.dart';
import 'package:quickfix/presentation/screens/booking/customer_booking_screen.dart';
import 'package:quickfix/presentation/screens/home/favourites_screen.dart';
import 'package:quickfix/presentation/screens/home/home_screen.dart';
import 'package:quickfix/presentation/screens/profile/profile_screen.dart';
import 'package:quickfix/presentation/screens/profile/provider_profile_screen.dart';
import 'package:quickfix/presentation/screens/provider/analytics_screen.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/screens/provider/create_service_screen.dart';
import 'package:quickfix/presentation/screens/provider/provider_dashboard_screen.dart';
import 'package:quickfix/presentation/screens/provider/provider_settings_screen.dart';
import 'package:quickfix/presentation/screens/splash/splash_screen.dart';
import 'package:quickfix/quickFix.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    navigatorKey: navigatorKey,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/user-type-selection';

      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }

      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != '/splash') {
        return '/user-type-selection';
      }

      return null;
    },

    routes: [
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
          final userType = state.uri.queryParameters['userType'] ?? 'customer';
          return LoginScreen(preselectedUserType: userType);
        },
      ),

      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) {
          final userType = state.uri.queryParameters['userType'] ?? 'customer';
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
    ],
  );
}
