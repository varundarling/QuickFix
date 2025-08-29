import 'package:flutter/material.dart';
import 'package:quickfix/core/services/fcm_http_service.dart';

class NotificationPermissionHelper {
  static Future<bool> showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Enable Notifications'),
              content: Text(
                'QuickFix would like to send you notifications about:\n\n'
                '• Service booking updates\n'
                '• New service availability\n'
                '• Important announcements\n\n'
                'You can change this setting anytime in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Not Now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Enable'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  static Future<void> requestPermissionWithDialog(BuildContext context) async {
    bool shouldRequest = await showPermissionDialog(context);

    if (shouldRequest) {
      String? fcmToken = await FCMTokenManager.getToken();

      if (fcmToken != null) {
        debugPrint('✅ Notifications enabled successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifications enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint('❌ Failed to enable notifications');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enable notifications. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
