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
  double get TotalAmount => _totalAmount;

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

  Future<void> loadProviderBookings(String providerId) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('providerId', isEqualTo: providerId)
            .orderBy('createdAt', descending: true),
      );

      _providerBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load provider bookings : $e');
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
      // _setLoading(true);

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

      await _firebaseService.createDocument(
        'bookings',
        bookingId,
        booking.toFireStore(),
      );

      //reload user bookings
      await loadUserBookings(customerId);

      return booking;
    } catch (e) {
      _setError('Failed to create booking: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      _setLoading(true);

      final updateData = <String, dynamic>{
        'status': status.toString().split('.').last,
      };

      if (status == BookingStatus.completed) {
        updateData['completedAt'] = DateTime.now();
      }

      await _firebaseService.updateDocument('bookings', bookingId, updateData);

      //update local booking
      final bookingIndex = _userBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != 1) {
        //reload bookings to get updated data
        await loadUserBookings(_userBookings[bookingIndex].customerId);
      }

      return true;
    } catch (e) {
      _setError('Failed to update bookings: $e');
      return false;
    } finally {
      _setLoading(false);
    }
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
