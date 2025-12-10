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

    try {
      final authProvider = context.read<AuthProvider>();

      // ✅ Ensure user data is loaded with retry logic
      if (authProvider.userModel == null) {
        await authProvider.reloadUserData();

        // Retry once more if still null
        if (authProvider.userModel == null) {
          await Future.delayed(const Duration(milliseconds: 500));
          await authProvider.reloadUserData();
        }
      }

      final user = authProvider.userModel;

      // ============= CASE 1: userModel is STILL null =================
      if (user == null) {
        // ✅ If caller supplied expected role (provider/customer/admin), prefer it
        if (expectedUserType != null) {
          final role = expectedUserType.toLowerCase();

          if (!context.mounted) return;

          if (role == 'admin') {
            // Admin → admin role selection screen
            context.go('/admin-role');
          } else if (role == 'provider' || role == 'serviceprovider') {
            context.go('/provider-dashboard');
          } else {
            context.go('/home');
          }
          return;
        }

        // ✅ FALLBACK: If still no user data and no hint, get user type directly
        try {
          final userType = await authProvider.getUserType();
          final type = userType.toLowerCase();

          if (!context.mounted) return;

          if (type == 'admin') {
            // ADMIN: always go to admin role selection
            context.go('/admin-role');
          } else if (type == 'provider' || type == 'serviceprovider') {
            context.go('/provider-dashboard');
          } else {
            context.go('/home');
          }
          return;
        } catch (e) {
          // Ultimate fallback - go to user type selection
          if (context.mounted) {
            context.go('/user-type-selection');
          }
          return;
        }
      }

      // ============= CASE 2: userModel is available =================
      final rawType = user.userType;
      final type = (rawType).toLowerCase();

      if (!context.mounted) return;

      if (type == 'admin') {
        // ✅ ADMIN: open admin role selection screen
        context.go('/admin-role');
      } else if (type == 'provider' || type == 'serviceprovider') {
        // ✅ PROVIDER
        context.go('/provider-dashboard');
      } else {
        // ✅ CUSTOMER (default)
        context.go('/home');
      }
    } finally {
      _isNavigating = false;
    }
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
