// lib/core/router/app_router.dart (Updated)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/presentation/screens/auth/login_screen.dart';
import 'package:quickfix/presentation/screens/auth/sign_Up_Screen.dart';
import 'package:quickfix/presentation/screens/auth/user_type_selection_screen.dart';
import 'package:quickfix/presentation/screens/booking/booking_details_screen.dart';
import 'package:quickfix/presentation/screens/booking/customer_booking_screen.dart';
import 'package:quickfix/presentation/screens/home/favourites_screen.dart';
import 'package:quickfix/presentation/screens/home/histroy_screen.dart';
import 'package:quickfix/presentation/screens/home/home_screen.dart';
import 'package:quickfix/presentation/screens/profile/profile_screen.dart';
import 'package:quickfix/presentation/screens/profile/provider_profile_screen.dart';
import 'package:quickfix/presentation/screens/provider/booking_detail_for_provider.dart';
import 'package:quickfix/presentation/screens/provider/create_service_screen.dart';
import 'package:quickfix/presentation/screens/provider/provider_dashboard_screen.dart';
import 'package:quickfix/presentation/screens/splash/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
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

      // ✅ NEW: History Screen
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
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
    ],
  );
}
