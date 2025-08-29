import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:quickfix/core/services/fcm_http_service.dart';
import 'dart:math';

class RealtimeNotificationService {
  static final RealtimeNotificationService _instance =
      RealtimeNotificationService._();
  static RealtimeNotificationService get instance => _instance;

  RealtimeNotificationService._();

  /// Notify nearby customers when provider creates a service
  Future<void> notifyNearbyCustomersOfNewService({
    required String serviceId,
    required String serviceTitle,
    required String location,
    required double latitude,
    required double longitude,
    required String category,
    required String providerId,
  }) async {
    try {
      debugPrint('🔔 Notifying nearby customers of new service...');

      // Get nearby customer tokens
      List<String> nearbyTokens = await _getNearbyCustomerTokens(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 10, // 10km radius
      );

      if (nearbyTokens.isEmpty) {
        debugPrint('📍 No nearby customers found');
        return;
      }

      // Send batch notifications
      int successCount = await FCMHttpService.instance.sendBatchNotifications(
        fcmTokens: nearbyTokens,
        title: "🔧 New $category Service Available",
        body: "$serviceTitle is now available near $location",
        data: {
          "screen": "service_details",
          "service_id": serviceId,
          "provider_id": providerId,
          "type": "new_service",
          "latitude": latitude.toString(),
          "longitude": longitude.toString(),
        },
      );

      debugPrint('✅ Notified $successCount nearby customers');
    } catch (e) {
      debugPrint('❌ Error notifying customers: $e');
    }
  }

  /// Notify provider when customer books their service
  Future<void> notifyProviderOfNewBooking({
    required String bookingId,
    required String providerId,
    required String customerName,
    required String serviceTitle,
    required DateTime scheduledDate,
    required String customerPhone,
  }) async {
    try {
      debugPrint('🔔 Notifying provider of new booking...');

      // First try to get provider's FCM token from providers collection
      DocumentSnapshot providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      // ✅ FIX: Cast to Map<String, dynamic> before accessing
      final providerData = providerDoc.data() as Map<String, dynamic>?;
      String? providerToken = providerData?['fcmToken'] as String?;

      // Fallback to users collection if token not found in providers
      if (providerToken == null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        // ✅ FIX: Cast to Map<String, dynamic> before accessing
        final userData = userDoc.data() as Map<String, dynamic>?;
        providerToken = userData?['fcmToken'] as String?;
      }

      if (providerToken == null || providerToken.isEmpty) {
        debugPrint('❌ Provider FCM token not found, notification aborted');
        return;
      }

      bool success = await FCMHttpService.instance.sendHighPriorityNotification(
        fcmToken: providerToken,
        title: "🎉 New Booking Request!",
        body:
            "$customerName booked $serviceTitle for ${_formatDate(scheduledDate)}",
        data: {
          "screen": "booking_details",
          "booking_id": bookingId,
          "customer_name": customerName,
          "customer_phone": customerPhone,
          "type": "new_booking",
          "scheduled_date": scheduledDate.toIso8601String(),
        },
      );

      if (success) {
        debugPrint('✅ Provider notified of new booking');
      } else {
        debugPrint('❌ Failed to notify provider');
      }
    } catch (e) {
      debugPrint('❌ Error notifying provider: $e');
    }
  }

  /// Get nearby customer FCM tokens within radius
  Future<List<String>> _getNearbyCustomerTokens({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    List<String> tokens = [];

    try {
      QuerySnapshot customers = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'customer')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in customers.docs) {
        // ✅ FIX: Cast to Map<String, dynamic> before accessing
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null ||
            data['fcmToken'] == null ||
            data['latitude'] == null ||
            data['longitude'] == null) {
          continue;
        }

        double customerLat = (data['latitude'] as num).toDouble();
        double customerLng = (data['longitude'] as num).toDouble();

        double distance = _calculateDistance(
          latitude,
          longitude,
          customerLat,
          customerLng,
        );

        if (distance <= radiusKm) {
          tokens.add(data['fcmToken'] as String);
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting nearby customers: $e');
    }

    return tokens;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
