import 'package:cloud_firestore/cloud_firestore.dart';
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
      final givenRating = rating; // capture for closure
      double newAvg = 0.0;
      int newCount = 0;

      // 1) Atomic aggregate on providers/{providerId}
      await _firestore.runTransaction((txn) async {
        final ref = _firestore.collection('providers').doc(providerId);
        final snap = await txn.get(ref);

        final prevCount = (snap.data()?['totalReviews'] ?? 0) as int;
        final prevAvg = ((snap.data()?['rating'] ?? 0.0) as num).toDouble();

        newCount = prevCount + 1;
        newAvg = ((prevAvg * prevCount) + givenRating) / newCount;

        txn.set(ref, {
          'rating': newAvg,
          'totalReviews': newCount,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // 2) Optional: mirror to users/{providerId} for profile pages that read there
      await _firestore.collection('users').doc(providerId).set({
        'rating': newAvg,
        'totalReviews': newCount,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Denormalize onto all services for customer list cards
      final servicesSnap = await _firestore
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .get();

      if (servicesSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in servicesSnap.docs) {
          batch.update(doc.reference, {
            'providerRating': newAvg,
            'providerTotalReviews': newCount,
            'lastRatingUpdate': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      return true;
    } catch (e) {
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
      return [];
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
      return {'averageRating': 0.0, 'totalReviews': 0};
    }
  }
}
