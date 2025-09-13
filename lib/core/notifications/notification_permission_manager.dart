import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPermissionManager {
  static Future<bool> requestNotificationPermission() async {
    try {
      // Check current permission status
      PermissionStatus status = await Permission.notification.status;

      if (status.isGranted) {
        
        return true;
      }

      // Request permission if not granted
      if (status.isDenied) {
        status = await Permission.notification.request();

        if (status.isGranted) {
          return true;
        } else if (status.isDenied) {
          return false;
        } else if (status.isPermanentlyDenied) {
          // Show dialog to open app settings
          await _showSettingsDialog();
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        await _showSettingsDialog();
        return false;
      }

      return false;
    } catch (e) {
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
        return token;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
