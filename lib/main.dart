import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quickfix/core/notifications/notification_channel.dart';
import 'package:quickfix/core/notifications/notification_permission_manager.dart';
import 'package:quickfix/core/services/location_service.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/core/utils/logger.dart';
import 'package:quickfix/presentation/providers/service_provider.dart';
import 'package:quickfix/quick_fix.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';

// Background message handler - must be top level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  //debugPrint('📱 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Core Firebase
  await FirebaseService.instance.initialize();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Ads and Notification stack init
  await AdService.instance.initialize();
  await NotificationChannels.createChannels(); // ensure channels exist before any local notif [high/urgent]
  await NotificationService.instance.initialize();

  // Request permissions at app open (notifications + location) and get FCM token
  await _preflightPermissions(); // ✅ NEW

  // Listen for token refresh events
  FCMTokenManager.initializeTokenListener();

  // One-time provider setup (existing)
  try {
    final serviceProvider = ServiceProvider();
    await serviceProvider.addAvailabilityToExistingServices();
  } catch (e) {
    Log.e('Error in one-time setup: $e');
  }

  Log.i('App initialization complete');
  runApp(const QuickFix());
}

Future _preflightPermissions() async {
  try {
    await NotificationPermissionManager.requestNotificationPermission();
  } catch (e) {
    Log.w('Notification permission request failed: $e');
  }

  try {
    await FCMTokenManager.getToken();
  } catch (e) {
    Log.w('FCM token prefetch failed: $e');
  }

  try {
    final granted = await LocationService.instance.requestPermission();
    if (!granted) {
      Log.w('Location permission denied at startup');
    }
    final isEnabled = await LocationService.instance.isLocationEnabled();
    if (!isEnabled) {
      await LocationService.instance.enableLocationService();
    }
  } catch (e) {
    Log.w('Location preflight failed: $e');
  }
}

class FCMTokenManager {
  static Future requestNotificationPermission() async {
    try {
      PermissionStatus status = await Permission.notification.status;
      if (status.isGranted) {
        Log.d('Notification permission already granted');
        return true;
      }
      if (status.isDenied) {
        status = await Permission.notification.request();
        return status.isGranted;
      }
      return false;
    } catch (e) {
      Log.e('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future getToken() async {
    try {
      bool permissionGranted = await requestNotificationPermission();
      if (!permissionGranted) {
        Log.w('Cannot get FCM token: Permission denied');
        return null;
      }

      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        Log.w('FCM permission denied');
        return null;
      }

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            Log.d('FCM Token obtained: ${token.substring(0, 20)}...');
            return token;
          }
        } catch (e) {
          Log.w('Token attempt $attempt failed: $e');
        }

        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
      return null;
    } catch (e) {
      Log.e('Error in getToken: $e');
      return null;
    }
  }

  static void initializeTokenListener() {
    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) {
          Log.d('Token refreshed: ${fcmToken.substring(0, 20)}...');
        })
        .onError((err) {
          Log.e('Error in token refresh: $err');
        });
  }
}
