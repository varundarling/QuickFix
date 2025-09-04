import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/data/models/rating_model.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();
  static RatingService get instance => _instance;
  RatingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a rating
  Future<bool> submitRating({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String serviceName,
    required String customerName,
    required double rating,
    required String review,
  }) async {
    try {
      // Check if rating already exists
      final existingRating = await _firestore
          .collection('ratings')
          .where('bookingId', isEqualTo: bookingId)
          .get();

      if (existingRating.docs.isNotEmpty) {
        throw Exception('Rating already exists for this booking');
      }

      // Create new rating
      final ratingRef = await _firestore.collection('ratings').add({
        'bookingId': bookingId,
        'customerId': customerId,
        'providerId': providerId,
        'serviceName': serviceName,
        'customerName': customerName,
        'rating': rating,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update booking with rating info
      await _firestore.collection('bookings').doc(bookingId).update({
        'ratingId': ratingRef.id,
        'isRated': true,
        'customerRating': rating,
        'hasCustomerReview': review.isNotEmpty,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // Update provider's overall rating
      await _updateProviderRating(providerId);

      return true;
    } catch (e) {
      debugPrint('❌ Error submitting rating: $e');
      return false;
    }
  }

  // Get rating for a specific booking
  Future<RatingModel?> getRatingForBooking(String bookingId) async {
    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('bookingId', isEqualTo: bookingId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return RatingModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting rating: $e');
      return null;
    }
  }

  // Get all ratings for a provider
  Future<List<RatingModel>> getProviderRatings(String providerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('ratings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting provider ratings: $e');
      return [];
    }
  }

  // Update provider's overall rating
  Future<void> _updateProviderRating(String providerId) async {
    try {
      final ratings = await getProviderRatings(providerId);

      if (ratings.isNotEmpty) {
        final averageRating =
            ratings.map((r) => r.rating).reduce((a, b) => a + b) /
            ratings.length;

        // Update in providers collection
        await _firestore.collection('providers').doc(providerId).update({
          'rating': averageRating,
          'totalReviews': ratings.length,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });

        // Also update in users collection for backward compatibility
        await _firestore.collection('users').doc(providerId).update({
          'rating': averageRating,
          'totalReviews': ratings.length,
        });
      }
    } catch (e) {
      debugPrint('❌ Error updating provider rating: $e');
    }
  }

  // Get provider's average rating
  Future<Map<String, dynamic>> getProviderRatingStats(String providerId) async {
    try {
      final ratings = await getProviderRatings(providerId);

      if (ratings.isEmpty) {
        return {'averageRating': 0.0, 'totalReviews': 0};
      }

      final averageRating =
          ratings.map((r) => r.rating).reduce((a, b) => a + b) / ratings.length;

      return {'averageRating': averageRating, 'totalReviews': ratings.length};
    } catch (e) {
      debugPrint('❌ Error getting rating stats: $e');
      return {'averageRating': 0.0, 'totalReviews': 0};
    }
  }
}
