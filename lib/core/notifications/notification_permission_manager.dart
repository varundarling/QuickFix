import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPermissionManager {
  static Future<bool> requestNotificationPermission() async {
    try {
      // Check current permission status
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        debugPrint('✅ Notification permission already granted');
        return true;
      }

      // Request permission if not granted
      if (status.isDenied) {
        debugPrint('🔔 Requesting notification permission...');
        status = await Permission.notification.request();

        if (status.isGranted) {
          debugPrint('✅ Notification permission granted by user');
          return true;
        } else if (status.isDenied) {
          debugPrint('❌ Notification permission denied by user');
          return false;
        } else if (status.isPermanentlyDenied) {
          debugPrint('❌ Notification permission permanently denied');
          // Show dialog to open app settings
          await _showSettingsDialog();
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        debugPrint('❌ Notification permission permanently denied');
        await _showSettingsDialog();
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> _showSettingsDialog() async {
    // You can implement a dialog to guide users to settings
    await openAppSettings();
  }

  // Combined FCM setup with permission request
  static Future<String?> setupFCMWithPermissions() async {
    try {
      // First request notification permission
      bool permissionGranted = await requestNotificationPermission();

      if (!permissionGranted) {
        debugPrint('❌ Cannot setup FCM: Permission denied');
        return null;
      }

      // Now request FCM token
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request FCM permission (iOS specific, harmless on Android)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        debugPrint('✅ FCM Token: ${token?.substring(0, 20)}...');
        return token;
      } else {
        debugPrint('❌ FCM permission denied');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error setting up FCM: $e');
      return null;
    }
  }
}
