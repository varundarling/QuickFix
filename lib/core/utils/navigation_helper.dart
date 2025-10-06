// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class NavigationHelper {
  static bool _isNavigating = false;
  static Future<void> navigateBasedOnRole(
    BuildContext context, {
    String? expectedUserType,
  }) async {
    if (_isNavigating) return; // prevent re-entrancy loops
    _isNavigating = true;
    final authProvider = context.read<AuthProvider>();
    // Show the app splash screen during handoff instead of a black overlay
    // try {
    //   if (context.mounted) {
    //     final location = GoRouter.of(context);
    //     if (location != '/splash') {
    //       context.push('/splash');
    //     }
    //   }
    // } catch (_) {}
    
    // ✅ ENHANCED: Ensure user data is loaded with retry logic
    if (authProvider.userModel == null) {
      await authProvider.reloadUserData();
      
      // ✅ ADDED: Retry mechanism if first reload fails
      if (authProvider.userModel == null) {
        // Wait a bit and try once more
        await Future.delayed(const Duration(milliseconds: 500));
        await authProvider.reloadUserData();
      }
    }

    final user = authProvider.userModel;
    if (user == null) {
      // ✅ If caller supplied expected role (provider/customer), prefer it when data isn't ready
      if (expectedUserType != null) {
        final role = expectedUserType.toLowerCase();
        if (context.mounted) {
          if (role == 'provider') {
            //debugPrint('🚀 Navigating to provider dashboard (hint)');
            context.go('/provider-dashboard');
          } else {
            //debugPrint('🚀 Navigating to customer home (hint)');
            context.go('/home');
          }
        }
        _isNavigating = false;
        return;
      }

      // ✅ FALLBACK: If still no user data and no hint, get user type directly from AuthProvider
      try {
        final userType = await authProvider.getUserType();
        //debugPrint('🔄 Using fallback user type: $userType');
        
        if (userType.toLowerCase() == 'provider') {
          if (context.mounted) {
            //debugPrint('🚀 Navigating to provider dashboard (fallback)');
            context.go('/provider-dashboard');
          }
          _isNavigating = false;
          return;
        } else {
          if (context.mounted) {
            //debugPrint('🚀 Navigating to customer home (fallback)');
            context.go('/home');
          }
          _isNavigating = false;
          return;
        }
      } catch (e) {
        //debugPrint('❌ Fallback navigation failed: $e');
        // Ultimate fallback - go to user type selection
        if (context.mounted) {
          context.go('/user-type-selection');
        }
        _isNavigating = false;
        return;
      }
    }

    // ✅ PRIMARY: Navigate based on userType field
    //debugPrint('🔍 User type from model: ${user.userType}');
    if (user.userType.toLowerCase() == 'provider') {
      if (context.mounted) {
        //debugPrint('🚀 Navigating to provider dashboard');
        context.go('/provider-dashboard');
      }
    } else {
      if (context.mounted) {
        // debugPrint('🚀 Navigating to customer home');
        context.go('/home');
      }
    }
    _isNavigating = false;
  }

  static void handleLogout(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Sign out and clear all data
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();

    // Close loading dialog
    if (context.mounted) Navigator.of(context).pop();

    // Navigate to user type selection for fresh start
    if (context.mounted) context.go('/user-type-selection');
  }
}