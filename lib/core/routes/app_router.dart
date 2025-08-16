import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/presentation/screens/auth/login_screen.dart';
import 'package:quickfix/presentation/screens/booking/booking_screen.dart';
import 'package:quickfix/presentation/screens/home/home_screen.dart';
import 'package:quickfix/presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/sign_up_Screen.dart';
import '../../presentation/screens/booking/booking_details_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/provider/provider_dashboard_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(  
    initialLocation: '/splash',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      
      // If user is logged in and trying to access login/signup, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }
      
      // If user is not logged in and trying to access protected routes, redirect to login
      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != '/splash') {
        return '/login';
      }
      
      return null; // No redirect
    },

    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      GoRoute(
        path: '/booking/:serviceId',
        name: 'booking',
        builder: (context, state) {
          final serviceId = state.pathParameters['serviceId']!;
          return BookingScreen(serviceId: serviceId);
        },
      ),

      GoRoute(
        path: '/booking-details/:bookingId',
        name: 'booking-details',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return BookingDetailsScreen(bookingId: bookingId);
        },
      ),

      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/provider-dashboard',
        name: 'provider-dashboard',
        builder: (context, state) => const ProviderDashboardScreen(),
      ),
    ],
  );
}


