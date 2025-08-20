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
  final Map<String, DateTime> _recentlyUpdatedBookings = {};

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

  Future<Map<String, dynamic>?> _fetchCustomerDetails(String customerId) async {
    try {
      final userDoc = await _firebaseService.getUserData(customerId);

      if (userDoc.exists) {
        final userData = userDoc.value as Map<dynamic, dynamic>;
        debugPrint(
          '✅ Found customer data: ${userData['name']}, ${userData['phone']}',
        );

        return {
          'customerName': userData['name']?.toString() ?? 'Unknown Customer',
          'customerPhone': userData['phone']?.toString() ?? 'No Phone',
          'customerEmail': userData['email']?.toString() ?? 'No Email',
        };
      } else {
        debugPrint('❌ Customer not found in Realtime Database');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching customer details: $e');
      return null;
    }
  }

  Future<void> loadUserBookings(String userId) async {
    try {
      _setLoading(true);

      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('customerId', isEqualTo: userId)
            .orderBy('createdAt', descending: true),
      );

      List<BookingModel> bookingsWithCustomerDetails = [];

      for (var doc in querySnapshot.docs) {
        // Create basic booking model
        BookingModel booking = BookingModel.fromFireStore(doc);

        // Fetch customer details
        final customerDetails = await _fetchCustomerDetails(booking.customerId);

        // Update booking with customer details
        if (customerDetails != null) {
          booking = booking.copyWith(
            customerName: customerDetails['customerName'],
            customerPhone: customerDetails['customerPhone'],
            customerEmail: customerDetails['customerEmail'],
          );
        }

        bookingsWithCustomerDetails.add(booking);
      }

      _providerBookings = bookingsWithCustomerDetails;

      _userBookings = bookingsWithCustomerDetails;

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
          (snapshot) async {
            debugPrint(
              '🔔 Received booking updates: ${snapshot.docs.length} bookings',
            );
            List<BookingModel> bookingsWithCustomerDetails = [];

            for (var doc in snapshot.docs) {
              BookingModel booking = BookingModel.fromFireStore(doc);

              // Fetch customer details for each booking
              final customerDetails = await _fetchCustomerDetails(
                booking.customerId,
              );

              if (customerDetails != null) {
                booking = booking.copyWith(
                  customerName: customerDetails['customerName'],
                  customerPhone: customerDetails['customerPhone'],
                  customerEmail: customerDetails['customerEmail'],
                );
                debugPrint(
                  '✅ Added customer details: ${booking.customerName}, ${booking.customerPhone}',
                );
              } else {
                debugPrint(
                  '⚠️ No customer details found for: ${booking.customerId.substring(0, 8)}',
                );
              }

              bookingsWithCustomerDetails.add(booking);
            }
            _providerBookings = bookingsWithCustomerDetails;

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

      List<BookingModel> bookingsWithCustomerDetails = [];

      for (var doc in querySnapshot.docs) {
        BookingModel booking = BookingModel.fromFireStore(doc);

        debugPrint(
          '📋 Processing booking: ${booking.id.substring(0, 8)} for customer: ${booking.customerId.substring(0, 8)}',
        );

        // Fetch customer details
        final customerDetails = await _fetchCustomerDetails(booking.customerId);

        if (customerDetails != null) {
          booking = booking.copyWith(
            customerName: customerDetails['customerName'],
            customerPhone: customerDetails['customerPhone'],
            customerEmail: customerDetails['customerEmail'],
          );
          debugPrint(
            '✅ Added customer details: ${booking.customerName}, ${booking.customerPhone}',
          );
        } else {
          debugPrint(
            '⚠️ No customer details found for: ${booking.customerId.substring(0, 8)}',
          );
        }

        bookingsWithCustomerDetails.add(booking);
      }

      _providerBookings = bookingsWithCustomerDetails;

      debugPrint(
        '✅ Loaded ${_providerBookings.length} provider bookings with customer details',
      );
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

      final customerDetails = await _fetchCustomerDetails(customerId);

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
        customerName: customerDetails?['customerName'],
        customerPhone: customerDetails?['customerPhone'],
        customerEmail: customerDetails?['customerEmail'],
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

  // ✅ Get in-progress bookings
  List<BookingModel> get activeBookings =>
      getBookingsByStatus(BookingStatus.inProgress);

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
    int bookingIndex = -1;
    BookingModel? originalBooking;

    try {
      debugPrint('🔄 Updating booking $bookingId to status: $status');

      // ✅ Find the booking first
      bookingIndex = _providerBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex == -1) {
        debugPrint('❌ Booking not found in local list');
        _setError('Booking not found');
        return false;
      }

      originalBooking = _providerBookings[bookingIndex];
      debugPrint('📋 Original booking status: ${originalBooking.status}');

      // ✅ Step 1: Update Firestore FIRST (no optimistic update)
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        _setError('Booking not found in database');
        return false;
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final serviceId = bookingData['serviceId'] as String;

      final batch = FirebaseFirestore.instance.batch();

      // Update booking status
      Map<String, dynamic> bookingUpdate = {
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (status == BookingStatus.completed) {
        bookingUpdate['completedAt'] = Timestamp.fromDate(DateTime.now());
      }

      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId);
      batch.update(bookingRef, bookingUpdate);

      // Update service availability
      final serviceRef = FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId);

      if (status == BookingStatus.confirmed) {
        batch.update(serviceRef, {
          'availability': 'booked',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } else if (status == BookingStatus.inProgress) {
        batch.update(serviceRef, {
          'availability': 'active',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } else if (status == BookingStatus.completed ||
          status == BookingStatus.cancelled) {
        batch.update(serviceRef, {
          'availability': 'available',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();
      debugPrint('✅ Firestore updated successfully');

      // ✅ Step 2: Update local state AFTER Firestore success
      final updatedBooking = originalBooking.copyWith(status: status);

      // ✅ Create a NEW list instance (critical for Flutter to detect changes)
      final newBookingsList = List<BookingModel>.from(_providerBookings);
      newBookingsList[bookingIndex] = updatedBooking;

      // ✅ Replace the entire list reference
      _providerBookings = newBookingsList;

      debugPrint(
        '✅ Local state updated: ${_providerBookings[bookingIndex].status}',
      );
      debugPrint('📊 Current booking counts after update:');
      debugPrint('   - Pending: ${pendingBookings.length}');
      debugPrint('   - Confirmed: ${confirmedBookings.length}');
      debugPrint('   - Active: ${activeBookings.length}');
      debugPrint('   - Completed: ${completedBookings.length}');

      // ✅ Force UI update
      if (hasListeners) {
        notifyListeners();
      }

      return true;
    } catch (error) {
      debugPrint('❌ Error updating booking status: $error');
      _setError('Failed to update booking status: $error');
      return false;
    }
  }

  Future<void> smartRefreshProviderBookings(String providerId) async {
    try {
      debugPrint('🔄 Smart refreshing provider bookings...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      final freshBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      // ✅ Merge strategy: keep recent local updates, use fresh data for others
      final now = DateTime.now();
      final mergedBookings = <String, BookingModel>{};

      // Start with fresh data
      for (var booking in freshBookings) {
        mergedBookings[booking.id] = booking;
      }

      // Preserve recently updated bookings (within last 2 minutes)
      for (var localBooking in _providerBookings) {
        final lastUpdate = _recentlyUpdatedBookings[localBooking.id];
        if (lastUpdate != null && now.difference(lastUpdate).inMinutes < 2) {
          debugPrint('🔄 Preserving recent update for ${localBooking.id}');
          mergedBookings[localBooking.id] = localBooking;
        }
      }

      // Clean up old entries
      _recentlyUpdatedBookings.removeWhere(
        (key, value) => now.difference(value).inMinutes > 5,
      );

      _providerBookings = mergedBookings.values.toList();
      _providerBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint(
        '✅ Smart refresh completed: ${_providerBookings.length} bookings',
      );

      if (hasListeners) {
        notifyListeners();
      }
    } catch (error) {
      debugPrint('❌ Error in smart refresh: $error');
    }
  }

  // ✅ Add this debug method to BookingProvider
  void debugBookingStates() {
    debugPrint('📊 Current booking states:');
    for (var booking in _providerBookings) {
      debugPrint(
        '   ${booking.serviceName}: ${booking.status} (ID: ${booking.id.substring(0, 8)})',
      );
    }
    debugPrint('📊 Pending: ${pendingBookings.length}');
    debugPrint('📊 Confirmed: ${confirmedBookings.length}');
    debugPrint('📊 Active: ${activeBookings.length}');
    debugPrint('📊 Completed: ${completedBookings.length}');
  }

  // ✅ Safe refresh that preserves recent local updates
  Future<void> safeRefreshProviderBookings(String providerId) async {
    try {
      debugPrint('🔄 Safe refreshing provider bookings...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      final freshBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      // ✅ Merge fresh data with any recent local updates
      final Map<String, BookingModel> mergedBookings = {};

      // Start with fresh data from Firestore
      for (var booking in freshBookings) {
        mergedBookings[booking.id] = booking;
      }

      // Override with any recent local updates (last 5 minutes)
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));
      for (var localBooking in _providerBookings) {
        final freshBooking = mergedBookings[localBooking.id];
        if (freshBooking != null) {
          // If local booking was recently updated, keep local version
          final localUpdatedAt =
              localBooking.createdAt; // Use updatedAt if available
          if (localUpdatedAt.isAfter(fiveMinutesAgo)) {
            debugPrint(
              '🔄 Preserving recent local update for ${localBooking.id}',
            );
            mergedBookings[localBooking.id] = localBooking;
          }
        }
      }

      _providerBookings = mergedBookings.values.toList();

      // Sort by creation date
      _providerBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint(
        '✅ Safe refresh completed: ${_providerBookings.length} bookings',
      );

      if (hasListeners) {
        notifyListeners();
      }
    } catch (error) {
      debugPrint('❌ Error in safe refresh: $error');
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

  void debugCurrentState(String operation) {
    debugPrint('📊 [$operation] Current booking state:');
    debugPrint('   - Total bookings: ${_providerBookings.length}');
    debugPrint('   - Pending: ${pendingBookings.length}');
    debugPrint('   - Confirmed: ${confirmedBookings.length}');
    debugPrint('   - Active (inProgress): ${activeBookings.length}');
    debugPrint('   - Completed: ${completedBookings.length}');

    debugPrint('📋 All bookings:');
    for (var booking in _providerBookings) {
      debugPrint(
        '   - ${booking.serviceName}: ${booking.status} (${booking.id.substring(0, 8)})',
      );
    }
  }
}
