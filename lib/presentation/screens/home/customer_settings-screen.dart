import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/presentation/providers/auth_provider.dart';
import 'package:quickfix/core/services/notification_service.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _bookingNotifications = true;
  bool _serviceUpdates = true;
  bool _promotionalNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _bookingNotifications = prefs.getBool('booking_notifications') ?? true;
        _serviceUpdates = prefs.getBool('service_updates') ?? true;
        _promotionalNotifications =
            prefs.getBool('promotional_notifications') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('booking_notifications', _bookingNotifications);
      await prefs.setBool('service_updates', _serviceUpdates);
      await prefs.setBool(
        'promotional_notifications',
        _promotionalNotifications,
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
      if (!value) {
        _bookingNotifications = false;
        _serviceUpdates = false;
        _promotionalNotifications = false;
      }
    });
    await _saveSettings();

    if (!value) {
      // Unsubscribe from all topics
      await NotificationService.instance.unsubscribeFrom('customers');
      await NotificationService.instance.unsubscribeFrom('promotions');
    } else {
      // Re-subscribe to customer notifications
      await NotificationService.instance.subscribeTo('customers');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Notifications enabled' : 'Notifications disabled',
          ),
          backgroundColor: value ? AppColors.success : Colors.orange,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to sign out?'),
            SizedBox(height: 8),
            Text(
              'You will need to sign in again to access your account.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authProvider = context.read<AuthProvider>();
        await authProvider.signOut();

        if (mounted) {
          context.go('/user-type-selection');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Section
                  _buildSectionHeader('Account'),
                  _buildAccountSection(),
                  const SizedBox(height: 24),

                  // Notification Settings
                  _buildSectionHeader('Notification Settings'),
                  _buildNotificationSection(),
                  const SizedBox(height: 24),

                  // App Settings
                  _buildSectionHeader('App Settings'),
                  _buildAppSection(),
                  const SizedBox(height: 32),

                  // Sign Out Button
                  _buildSignOutButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                title: const Text('My Profile '),
                subtitle: const Text('Manage your personal information'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/profile'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bookmark, color: Colors.blue),
                ),
                title: const Text('My Bookings'),
                subtitle: const Text('View and manage your bookings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/customer-bookings'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red),
                ),
                title: const Text('Favorites'),
                subtitle: const Text('Your saved services'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/favorites'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive all app notifications'),
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _notificationsEnabled
                    ? AppColors.success.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _notificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_off,
                color: _notificationsEnabled ? AppColors.success : Colors.grey,
              ),
            ),
          ),
          if (_notificationsEnabled) ...[
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Booking Notifications'),
              subtitle: const Text('Updates about your bookings'),
              value: _bookingNotifications,
              onChanged: (value) async {
                setState(() {
                  _bookingNotifications = value;
                });
                await _saveSettings();
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.blue),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Service Updates'),
              subtitle: const Text('New services and availability'),
              value: _serviceUpdates,
              onChanged: (value) async {
                setState(() {
                  _serviceUpdates = value;
                });
                await _saveSettings();
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.update, color: Colors.green),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Promotional Notifications'),
              subtitle: const Text('Special offers and discounts'),
              value: _promotionalNotifications,
              onChanged: (value) async {
                setState(() {
                  _promotionalNotifications = value;
                });
                await _saveSettings();
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_offer, color: Colors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info, color: Colors.orange),
            ),
            title: const Text('About QuickFix'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About QuickFix'),
                  content: const Text(
                    'QuickFix Customer\nVersion 1.0.0\n\nFind and book quality services from trusted providers.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          // const Divider(height: 1),
          // ListTile(
          //   leading: Container(
          //     padding: const EdgeInsets.all(8),
          //     decoration: BoxDecoration(
          //       color: Colors.green.withOpacity(0.1),
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //     child: const Icon(Icons.help, color: Colors.green),
          //   ),
          //   title: const Text('Help & Support'),
          //   subtitle: const Text('Get help or contact support'),
          //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          //   onTap: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(content: Text('Support feature coming soon!')),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'Sign Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
