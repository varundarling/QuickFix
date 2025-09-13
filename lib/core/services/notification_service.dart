import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickfix/core/services/fcm_http_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notifications_enabled') ?? true;

  if (!enabled) {
    return;
  }
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await FCMHttpService.instance.initialize();
      await _requestPermissions();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      // Initialize local notifications (for in-app notifications)
      await _initializeLocalNotifications();

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Start listening for notifications in Firestore
      _startListeningForNotifications();

      _isInitialized = true;
    } catch (e) {
      // Handle initialization errors
    }
  }

  Future<void> createNotificationChannel() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> notifyAllCustomersOfNewService({
    required String serviceName,
    required String category,
    required String serviceId,
    required String location,
  }) async {
    try {
      // ✅ FIXED: Get all customer FCM tokens instead of using topic
      QuerySnapshot customersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'customer')
          .where('isActive', isEqualTo: true)
          .get();

      List<String> customerTokens = [];

      for (var doc in customersQuery.docs) {
        final userData = doc.data() as Map<String, dynamic>?;
        final fcmToken = userData?['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          customerTokens.add(fcmToken);
        }
      }

      if (customerTokens.isEmpty) {
        return;
      }

      // ✅ Create individual notification documents for each customer
      final batch = FirebaseFirestore.instance.batch();

      for (String fcmToken in customerTokens) {
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'fcmToken': fcmToken, // ✅ Individual FCM token
          'title': 'New Service Available! 🔧',
          'body': '$serviceName is now available in $location',
          'data': {
            'type': 'new_service',
            'serviceId': serviceId,
            'category': category,
            'screen': 'service_details',
          },
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // ✅ ALSO send via HTTP API for immediate delivery
      await FCMHttpService.instance.sendBatchNotifications(
        fcmTokens: customerTokens,
        title: 'New Service Available! 🔧',
        body: '$serviceName is now available in $location',
        data: {
          'type': 'new_service',
          'serviceId': serviceId,
          'category': category,
          'screen': 'service_details',
        },
      );
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> notifyProviderOfBooking({
    required String providerId,
    required String serviceName,
    required String customerName,
    required String bookingId,
  }) async {
    try {
      // First try to get provider's FCM token from providers collection
      DocumentSnapshot providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      String? fcmToken;

      if (providerDoc.exists && providerDoc.data() != null) {
        final providerData = providerDoc.data() as Map<String, dynamic>;
        fcmToken = providerData['fcmToken'] as String?;
      }

      // Fallback to users collection if token not found in providers
      if (fcmToken == null || fcmToken.isEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          fcmToken = userData['fcmToken'] as String?;
        }
      }

      // ✅ CRITICAL: Get fresh FCM token if still not found
      if (fcmToken == null || fcmToken.isEmpty) {
        fcmToken = await FCMTokenManager.getToken();

        if (fcmToken != null) {
          // Save the fresh token to both collections
          await _saveFreshTokenToCollections(providerId, fcmToken);
        }
      }

      if (fcmToken == null || fcmToken.isEmpty) {
        return;
      }

      // ✅ FIXED: Use fcmToken instead of targetTopic for provider notifications
      await FirebaseFirestore.instance.collection('notifications').add({
        'fcmToken': fcmToken, // ✅ Use fcmToken for individual notifications
        'targetUserId': providerId, // ✅ Keep targetUserId for filtering
        'title': 'New Booking! 📅',
        'body': '$customerName booked your $serviceName service',
        'data': {
          'type': 'new_booking',
          'bookingId': bookingId,
          'providerId': providerId,
          'screen': 'booking_details',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ ALSO send via HTTP API for immediate delivery
      final httpSuccess = await FCMHttpService.instance
          .sendHighPriorityNotification(
            fcmToken: fcmToken,
            title: 'New Booking! 📅',
            body: '$customerName booked your $serviceName service',
            data: {
              'type': 'new_booking',
              'bookingId': bookingId,
              'providerId': providerId,
              'screen': 'booking_details',
            },
          );

      if (httpSuccess) {
        // Notification sent successfully
      }
    } catch (e) {
      // Handle errors
    }
  }

  // ✅ NEW: Helper method to save fresh token to both collections
  Future<void> _saveFreshTokenToCollections(
    String userId,
    String fcmToken,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Save to users collection
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      batch.set(userRef, {
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save to providers collection
      final providerRef = FirebaseFirestore.instance
          .collection('providers')
          .doc(userId);
      batch.set(providerRef, {
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _requestPermissions() async {
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Permissions granted
    } else {
      // Handle errors
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // ✅ STEP 3: Check if notifications are enabled before showing
    final enabled = await areNotificationsEnabled();

    if (!enabled) {
      return;
    }

    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'QuickFix',
        body: message.notification!.body ?? '',
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    _navigateToRelevantScreen(message.data);
  }

  Future<void> sendDirectFCMNotification({
    required String? fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (fcmToken == null) return;

    try {
      // This would require your server-side implementation
      // For now, we'll create the Firestore document as before
      await FirebaseFirestore.instance.collection('notifications').add({
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload as RemoteMessage);
      },
    );
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<void> updateUserToken(String userId) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> subscribeTo(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> unsubscribeFrom(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      // Handle errors
    }
  }

  // ✅ NEW: Listen for notification documents in real-time
  void _startListeningForNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Listen for notifications targeted at this user or all customers
    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((QuerySnapshot snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final notification = change.doc.data() as Map<String, dynamic>;
              _processIncomingNotification(notification, change.doc.id);
            }
          }
        });
  }

  Future<void> _processIncomingNotification(
    Map<String, dynamic> notification,
    String notificationId,
  ) async {
    try {
      final enabled = await areNotificationsEnabled();
      if (!enabled) {
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final targetUserId = notification['targetUserId'] as String?;
      final targetTopic = notification['targetTopic'] as String?;
      final title = notification['title'] as String? ?? 'Notification';
      final body = notification['body'] as String? ?? '';

      // Check if this notification is for the current user
      bool isForThisUser = false;

      if (targetUserId != null && targetUserId == currentUser.uid) {
        isForThisUser = true; // Direct user notification
      } else if (targetTopic == 'customers') {
        // Check if current user is a customer
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        // ✅ FIX: Cast to Map<String, dynamic> before accessing
        final userData = userDoc.data();
        final userType = userData?['userType'] as String?;
        isForThisUser = userType == 'customer';
      }

      if (isForThisUser) {
        // ✅ FIX: Safe access to notification data
        final notificationData = notification['data'];
        Map<String, dynamic> payload = {};
        if (notificationData != null && notificationData is Map) {
          payload = Map<String, dynamic>.from(notificationData);
        }

        // Show local notification
        await _showLocalNotification(
          title: title,
          body: body,
          payload: jsonEncode(payload),
        );

        // Mark notification as processed for this user
        await _markNotificationAsProcessed(notificationId, currentUser.uid);
      }
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _markNotificationAsProcessed(
    String notificationId,
    String userId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .collection('processedBy')
          .doc(userId)
          .set({'processedAt': FieldValue.serverTimestamp(), 'userId': userId});

      // Optionally, clean up old notifications
      _cleanupOldNotifications(notificationId);
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _cleanupOldNotifications(String notificationId) async {
    try {
      // Delete notifications older than 1 hour
      DateTime.now().subtract(const Duration(hours: 1));

      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
            'status': 'processed',
            'processedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // Handle errors
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'quickfix_notifications',
          'QuickFix Notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void _navigateToRelevantScreen(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'new_service':
        // Navigate to service details
        break;
      case 'new_booking':
        // Navigate to bookings screen
        break;
      case 'status_update':
        // Navigate to booking status
        break;
    }
  }

  // // ✅ NEW: Create notification for provider (Spark plan compatible)
  // Future<void> notifyProviderOfBooking({
  //   required String providerId,
  //   required String serviceName,
  //   required String customerName,
  //   required String bookingId,
  // }) async {
  //   try {
  //     await FirebaseFirestore.instance.collection('notifications').add({
  //       'targetUserId': providerId,
  //       'title': 'New Booking! 📅',
  //       'body': '$customerName booked your $serviceName service',
  //       'data': {'type': 'new_booking', 'bookingId': bookingId},
  //       'status': 'pending',
  //       'createdAt': FieldValue.serverTimestamp(),
  //     });

  //     
  //   } catch (e) {
  //     // Handle errors
  //   }
  // }

  Future<void> notifyCustomerOfStatusChange({
    required String customerId,
    required String serviceName,
    required String status,
    required String bookingId,
  }) async {
    String title = '';
    String body = '';

    switch (status.toLowerCase()) {
      case 'confirmed':
        title = 'Booking Confirmed! ✅';
        body = 'Your $serviceName booking has been accepted';
        break;
      case 'started':
        title = 'Service Started! 🚀';
        body = 'Your $serviceName service has begun';
        break;
      case 'completed':
        title = 'Service Completed! 🎉';
        body = 'Your $serviceName service is now complete';
        break;
      default:
        title = 'Booking Update';
        body = 'Your $serviceName booking status: $status';
    }

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetUserId': customerId,
        'title': title,
        'body': body,
        'data': {
          'type': 'status_update',
          'bookingId': bookingId,
          'status': status,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      
    } catch (e) {
      //Handle errors
    }
  }

  Future<void> notifyProviderOfPaymentReceived({
    required String providerId,
    required String serviceName,
    required String customerName,
    required String bookingId,
    required double paymentAmount,
  }) async {
    try {

      // Get provider FCM token
      String? fcmToken = await _getProviderFCMToken(providerId);

      if (fcmToken == null || fcmToken.isEmpty) {
        return;
      }

      // Create Firestore notification document
      await FirebaseFirestore.instance.collection('notifications').add({
        'fcmToken': fcmToken,
        'targetUserId': providerId,
        'title': '💰 Payment Received!',
        'body': '$customerName paid ₹${paymentAmount.toInt()} for $serviceName',
        'data': {
          'type': 'payment_received',
          'bookingId': bookingId,
          'providerId': providerId,
          'paymentAmount': paymentAmount.toString(),
          'screen': 'booking_details',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send via HTTP API for immediate delivery
      final httpSuccess = await FCMHttpService.instance
          .sendHighPriorityNotification(
            fcmToken: fcmToken,
            title: '💰 Payment Received!',
            body:
                '$customerName paid ₹${paymentAmount.toInt()} for $serviceName',
            data: {
              'type': 'payment_received',
              'bookingId': bookingId,
              'providerId': providerId,
              'paymentAmount': paymentAmount.toString(),
              'screen': 'booking_details',
            },
          );

      if (httpSuccess) {
        // Notification sent successfully
      }
    } catch (e) {
      // Handle errors
    }
  }

  // Helper method to get provider FCM token (reusable)
  Future<String?> _getProviderFCMToken(String providerId) async {
    try {
      // First try providers collection
      DocumentSnapshot providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      String? fcmToken;

      if (providerDoc.exists && providerDoc.data() != null) {
        final providerData = providerDoc.data() as Map<String, dynamic>;
        fcmToken = providerData['fcmToken'] as String?;
      }

      // Fallback to users collection
      if (fcmToken == null || fcmToken.isEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          fcmToken = userData['fcmToken'] as String?;
        }
      }

      // Get fresh token if still not found
      if (fcmToken == null || fcmToken.isEmpty) {
        fcmToken = await FCMTokenManager.getToken();
        if (fcmToken != null) {
          await _saveFreshTokenToCollections(providerId, fcmToken);
        }
      }

      return fcmToken;
    } catch (e) {
      return null;
    }
  }

  static Future<void> disableNotifications() async {
    try {
      // 1. Unsubscribe from ALL topics
      await _messaging.unsubscribeFromTopic('customers');
      await _messaging.unsubscribeFromTopic('promotions');
      await _messaging.unsubscribeFromTopic('all');

      // 2. Delete the FCM token (this is crucial!)
      await _messaging.deleteToken();

      // 3. Save preference locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', false);
    } catch (e) {
      // Handle errors
    }
  }

  static Future<void> enableNotifications() async {
    try {
      // 1. Generate new FCM token
      await _messaging.getToken();

      // 2. Re-subscribe to topics
      await _messaging.subscribeToTopic('customers');

      // 3. Save preference locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);

    } catch (e) {
      // Handle errors
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  void dispose() {
    _notificationSubscription?.cancel();
  }
}
