import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:js/js.dart';


const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ✅ Main function: Send notification when document is created
exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notificationId = context.params.notificationId;

    console.log(`Processing notification: ${notificationId}`);

    if (!notification) {
      console.error('No notification data available');
      return null;
    }

    const { targetUserId, targetTopic, title, body, data, fcmToken } = notification;

    // Build FCM message
    const message = {
      notification: {
        title: title || 'QuickFix Notification',
        body: body || '',
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      let result;

      if (targetUserId && fcmToken) {
        // Send to specific user
        message.token = fcmToken;
        result = await admin.messaging().send(message);
        console.log(`✅ Notification sent to user ${targetUserId}: ${result}`);

      } else if (targetTopic) {
        // Send to topic (e.g., all customers)
        message.topic = targetTopic;
        result = await admin.messaging().send(message);
        console.log(`✅ Notification sent to topic ${targetTopic}: ${result}`);

      } else {
        console.warn('❌ No valid target (userId or topic) specified');
        await snap.ref.delete();
        return null;
      }

      // ✅ Delete notification document after successful send
      await snap.ref.delete();
      console.log(`🗑️ Notification document ${notificationId} deleted`);

      // Optional: Log successful delivery
      await admin.firestore().collection('notification_logs').add({
        notificationId: notificationId,
        type: targetTopic ? 'topic' : 'user',
        target: targetTopic || targetUserId,
        title,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: result,
        status: 'delivered',
      });

      return null;

    } catch (error) {
      console.error(`❌ Error processing notification ${notificationId}:`, error);

      // Update document with error status instead of deleting
      await snap.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    }
  });

// ✅ Cleanup function: Remove failed notifications older than 1 hour
exports.cleanupFailedNotifications = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of failed notifications');

    const cutoffTime = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 60 * 60 * 1000) // 1 hour ago
    );

    const failedDocs = await admin.firestore()
      .collection('notifications')
      .where('status', '==', 'failed')
      .where('createdAt', '<', cutoffTime)
      .get();

    if (failedDocs.empty) {
      console.log('✅ No failed notifications to clean up');
      return null;
    }

    const batch = admin.firestore().batch();
    failedDocs.forEach(doc => batch.delete(doc.ref));

    await batch.commit();
    console.log(`🧹 Cleaned up ${failedDocs.size} failed notifications`);

    return null;
  });
