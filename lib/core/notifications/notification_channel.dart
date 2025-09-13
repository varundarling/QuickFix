import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationChannels {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> createChannels() async {
    // Create urgent notification channel
    const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
      'urgent_notifications',
      'Urgent Notifications',
      description: 'Critical notifications that require immediate attention',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
    );

    // Create high importance channel
    const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Important notifications for bookings and services',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(urgentChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(highChannel);
  }

  // ✅ Example: Show notification using the created channel
  static Future<void> showUrgentNotification({
    required String title,
    required String body,
  }) async {
    // ✅ Here you CAN use both 'importance' and 'priority'
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'urgent_notifications', // Must match channel ID
          'Urgent Notifications',
          channelDescription:
              'Critical notifications that require immediate attention',
          importance: Importance.max,
          priority: Priority.high, // ✅ Valid for AndroidNotificationDetails
          showWhen: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(0, title, body, notificationDetails);
  }
}
