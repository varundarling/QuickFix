import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/service_model.dart';
import 'package:uuid/uuid.dart';

class BookingProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService.instance;
  final Uuid _uuid = const Uuid();

  List<BookingModel> _userBookings = [];
  List<BookingModel> _providerBookings = [];
  bool _isLoading = false;
  String? _errorMessage;

  //booking creation feilds
  String? _selectedServiceId;
  String? _selectedProviderId;
  DateTime? _selectedDateTime;
  String _description = '';
  String _customerAddress = '';
  double? _customerLatitude;
  double? _customerLongitude;
  double _totalAmount = 0.0;

  List<BookingModel> get userBookings => _userBookings;
  List<BookingModel> get providerbookings => _providerBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  //getters for booking creation
  String? get selectedServiceId => _selectedServiceId;
  String? get selectedProviderId => _selectedProviderId;
  DateTime? get selectedDateTime => _selectedDateTime;
  String get description => _description;
  String get customerAddress => _customerAddress;
  double get totalAmount => _totalAmount;

  Future<void> loadUserBookings(String userId) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('customerId', isEqualTo: userId)
            .orderBy('createdAt', descending: true),
      );

      _userBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load bookings:$e');
    } finally {
      _setLoading(false);
    }
  }

  StreamSubscription<QuerySnapshot>? _providerBookingsSubscription;

  // ✅ Add real-time listener for provider bookings
  void listenToProviderBookings(String providerId) {
    debugPrint('🔄 Setting up real-time listener for provider: $providerId');

    // Cancel existing subscription if any
    _providerBookingsSubscription?.cancel();

    _providerBookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '🔔 Received booking updates: ${snapshot.docs.length} bookings',
            );

            _providerBookings = snapshot.docs
                .map((doc) => BookingModel.fromFireStore(doc))
                .toList();

            debugPrint(
              '✅ Updated provider bookings: ${_providerBookings.length}',
            );
            debugPrint('✅ Pending: ${pendingBookings.length}');
            debugPrint('✅ Confirmed: ${confirmedBookings.length}');
            debugPrint('✅ Completed: ${completedBookings.length}');

            if (hasListeners) {
              notifyListeners();
            } // ✅ This triggers UI rebuild
          },
          onError: (error) {
            debugPrint('❌ Error listening to bookings: $error');
            _setError('Failed to listen to bookings: $error');
          },
        );
  }

  void stopListeningToProviderBookings() {
    _providerBookingsSubscription?.cancel();
    _providerBookingsSubscription = null;
    debugPrint('🛑 Stopped listening to provider bookings');
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing BookingProvider');
    stopListeningToProviderBookings();
    super.dispose();
  }

  // ✅ Keep the existing method but add notifyListeners
  Future<void> loadProviderBookings(String providerId) async {
    try {
      _setLoading(true);
      clearError();

      debugPrint('🔄 Loading provider bookings for: $providerId');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      _providerBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      debugPrint('✅ Loaded ${_providerBookings.length} provider bookings');
      debugPrint('✅ Pending: ${pendingBookings.length}');
      debugPrint('✅ Confirmed: ${confirmedBookings.length}');
      debugPrint('✅ Completed: ${completedBookings.length}');

      notifyListeners(); // ✅ Ensure UI updates
    } catch (error) {
      _setError('Failed to load bookings: $error');
      debugPrint('❌ Error loading provider bookings: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<BookingModel?> createBooking({
    required String customerId,
    required String providerId,
    required ServiceModel service,
    required DateTime scheduledDateTime,
    required String description,
    required String customerAddress,
    required double customerLatitude,
    required double customerLongitude,
    required double totalAmount,
  }) async {
    try {
      _setLoading(true);

      final bookingId = _uuid.v4();
      final booking = BookingModel(
        id: bookingId,
        customerId: customerId,
        providerId: providerId,
        serviceId: service.id,
        serviceName: service.name,
        scheduledDateTime: scheduledDateTime,
        description: description,
        totalAmount: totalAmount,
        status: BookingStatus.pending,
        customerAddress: customerAddress,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
        createdAt: DateTime.now(),
      );

      // ✅ Use batch write to update both booking and service availability
      final batch = FirebaseFirestore.instance.batch();

      // Add booking document
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId);
      batch.set(bookingRef, booking.toFireStore());

      // ✅ Update service availability to 'booked'
      final serviceRef = FirebaseFirestore.instance
          .collection('services')
          .doc(service.id);
      batch.update(serviceRef, {
        'availability': 'booked',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await batch.commit();

      debugPrint(
        '✅ Booking created and service marked as booked: ${service.name}',
      );

      // Reload user bookings
      await loadUserBookings(customerId);

      return booking;
    } catch (e) {
      debugPrint('❌ Error creating booking: $e');
      _setError('Failed to create booking: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  List<BookingModel> getBookingsByStatus(BookingStatus status) {
    return _providerBookings
        .where((booking) => booking.status == status)
        .toList();
  }

  // ✅ Get pending bookings
  List<BookingModel> get pendingBookings =>
      getBookingsByStatus(BookingStatus.pending);

  // ✅ Get confirmed bookings
  List<BookingModel> get confirmedBookings =>
      getBookingsByStatus(BookingStatus.confirmed);

  // ✅ Get completed bookings
  List<BookingModel> get completedBookings =>
      getBookingsByStatus(BookingStatus.completed);

  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus status,
    String providerId,
  ) async {
    try {
      // Get booking data first to access serviceId
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        _setError('Booking not found');
        return false;
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final serviceId = bookingData['serviceId'] as String;

      // ✅ Use batch write to update both booking and service
      final batch = FirebaseFirestore.instance.batch();

      // Update booking status
      Map<String, dynamic> bookingUpdate = {
        'status': status.toString().split('.').last,
      };

      if (status == BookingStatus.completed) {
        bookingUpdate['completedAt'] = Timestamp.fromDate(DateTime.now());
      }

      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId);
      batch.update(bookingRef, bookingUpdate);

      // ✅ Update service availability based on booking status
      final serviceRef = FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId);

      if (status == BookingStatus.inProgress) {
        // When provider starts service
        batch.update(serviceRef, {
          'availability': 'active',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        debugPrint('✅ Service marked as active (in progress)');
      } else if (status == BookingStatus.completed ||
          status == BookingStatus.cancelled) {
        // When service is completed or cancelled, make it available again
        batch.update(serviceRef, {
          'availability': 'available',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
        debugPrint('✅ Service marked as available again');
      }

      await batch.commit();

      // Reload provider bookings
      await loadProviderBookings(providerId);

      debugPrint(
        '✅ Booking status updated: $bookingId -> ${status.toString()}',
      );
      return true;
    } catch (error) {
      _setError('Failed to update booking status: $error');
      debugPrint('❌ Error updating booking status: $error');
      return false;
    }
  }

  Stream<List<BookingModel>> getProviderBookingsStream(String providerId) {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFireStore(doc))
              .toList(),
        );
  }

  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc = await _firebaseService.getDocument('bookings', bookingId);
      if (doc.exists) {
        return BookingModel.fromFireStore(doc);
      }
      return null;
    } catch (e) {
      _setError('Failed to get booking: $e');
      return null;
    }
  }

  //booking creation methods
  void setSelectedService(String serviceId) {
    _selectedServiceId = serviceId;
    notifyListeners();
  }

  void setSelectedProvider(String providerId) {
    _selectedProviderId = providerId;
    notifyListeners();
  }

  void setSelectedDateTime(DateTime dateTime) {
    _selectedDateTime = dateTime;
    notifyListeners();
  }

  void setDesciption(String description) {
    _description = description;
    notifyListeners();
  }

  void setCustomerLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    _customerAddress = address;
    _customerLatitude = latitude;
    _customerLongitude = longitude;
    notifyListeners();
  }

  void setTotalAmount(double amount) {
    _totalAmount = amount;
    notifyListeners();
  }

  void clearBookingData() {
    _selectedServiceId = null;
    _selectedProviderId = null;
    _selectedDateTime = null;
    _description = '';
    _customerAddress = '';
    _customerLatitude = null;
    _customerLongitude = null;
    _totalAmount = 0.0;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
