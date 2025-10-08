import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quickfix/core/notifications/notification_channel.dart';
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
  debugPrint('📱 Background message received: ${message.messageId}');
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
  MobileAds.instance.initialize();
  await AdService.instance.initialize();
  await NotificationChannels.createChannels(); // ensure channels exist before any local notif [high/urgent]
  await NotificationService.instance.initialize();

  // REMOVED: Permission requests - will be handled in HomeScreen/ProviderDashboard

  // Listen for token refresh events (keep this for when permissions are granted later)
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

// Keep FCM Token Manager for when permissions are granted later
class FCMTokenManager {
  static Future<String?> getToken() async {
    try {
      // Only get token if permissions are already granted
      NotificationSettings settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        Log.w('FCM permission not granted yet');
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
