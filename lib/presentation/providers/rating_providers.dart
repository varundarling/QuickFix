import 'package:flutter/material.dart';
import 'package:quickfix/core/services/rating_service.dart';
import 'package:quickfix/data/models/rating_model.dart';

class RatingProvider extends ChangeNotifier {
  final RatingService _ratingService = RatingService.instance;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, RatingModel> _bookingRatings = {};
  Map<String, Map<String, dynamic>> _providerStats = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Submit a new rating
  Future<bool> submitRating({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String serviceName,
    required String customerName,
    required double rating,
    required String review,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _ratingService.submitRating(
        bookingId: bookingId,
        customerId: customerId,
        providerId: providerId,
        serviceName: serviceName,
        customerName: customerName,
        rating: rating,
        review: review,
      );

      if (success) {
        // Cache the rating locally
        final ratingModel = RatingModel(
          id: bookingId,
          bookingId: bookingId,
          customerId: customerId,
          providerId: providerId,
          serviceName: serviceName,
          rating: rating,
          review: review,
          customerName: customerName,
          createdAt: DateTime.now(),
        );
        _bookingRatings[bookingId] = ratingModel;

        // Refresh provider stats
        await loadProviderRatingStats(providerId);
      }

      return success;
    } catch (e) {
      _setError('Failed to submit rating: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get rating for a specific booking
  Future<RatingModel?> getRatingForBooking(String bookingId) async {
    // Check cache first
    if (_bookingRatings.containsKey(bookingId)) {
      return _bookingRatings[bookingId];
    }

    try {
      final rating = await _ratingService.getRatingForBooking(bookingId);
      if (rating != null) {
        _bookingRatings[bookingId] = rating;
      }
      return rating;
    } catch (e) {
      debugPrint('❌ Error getting rating: $e');
      return null;
    }
  }

  // Load provider rating statistics
  Future<void> loadProviderRatingStats(String providerId) async {
    try {
      final stats = await _ratingService.getProviderRatingStats(providerId);
      _providerStats[providerId] = stats;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading provider stats: $e');
    }
  }

  // Get cached provider stats
  Map<String, dynamic>? getProviderStats(String providerId) {
    return _providerStats[providerId];
  }

  // Check if booking has been rated
  bool hasRatedBooking(String bookingId) {
    return _bookingRatings.containsKey(bookingId);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
