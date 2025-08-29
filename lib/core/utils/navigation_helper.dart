import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';

class NavigationHelper {
  static Future<void> navigateBasedOnRole(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    // Ensure user data is loaded
    if (authProvider.userModel == null) {
      await authProvider.reloadUserData();
    }

    final user = authProvider.userModel;

    if (user == null) {
      // Not logged in, go to user type selection
      if (context.mounted) {
        context.go('/user-type-selection');
      }
      return;
    }

    // Navigate based on userType field
    if (user.userType.toLowerCase() == 'provider') {
      if (context.mounted) {
        context.go('/provider-dashboard');
      }
    } else {
      if (context.mounted) {
        context.go('/home');
      }
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
    if (context.mounted) {
      context.go('/user-type-selection');
    }
  }
}
