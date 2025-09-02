import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/core/services/ad_service.dart';
import 'package:quickfix/core/services/fcm_http_service.dart';
import 'package:quickfix/core/services/firebase_service.dart';
import 'package:quickfix/core/services/notification_service.dart';
import 'package:quickfix/core/services/otp_service.dart';
import 'package:quickfix/core/services/realtime_notification_service.dart';
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

  bool _isUpdatingStatus = false;
  String? _currentProviderId;
  StreamSubscription<QuerySnapshot>? _providerBookingsSubscription;

  String? _selectedServiceId;
  String? _selectedProviderId;
  DateTime? _selectedDateTime;
  String _description = '';
  String _customerAddress = '';
  double? _customerLatitude;
  double? _customerLongitude;
  double _totalAmount = 0.0;

  String? get selectedServiceId => _selectedServiceId;
  String? get selectedProviderId => _selectedProviderId;
  DateTime? get selectedDateTime => _selectedDateTime;
  String get description => _description;
  String get customerAddress => _customerAddress;
  double get totalAmount => _totalAmount;

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

  // ✅ ADD: Debug methods
  void debugCurrentState(String operation) {
    debugPrint('📊 [$operation] Current booking state:');
    debugPrint('   - Total bookings: ${_providerBookings.length}');
    debugPrint('   - Pending: ${pendingBookings.length}');
    debugPrint('   - Confirmed: ${confirmedBookings.length}');
    debugPrint('   - Active (confirmed): ${activeBookings.length}');
    debugPrint('   - Completed: ${completedBookings.length}');

    debugPrint('📋 All bookings:');
    for (var booking in _providerBookings) {
      debugPrint(
        '   - ${booking.serviceName}: ${booking.status} (${booking.id.substring(0, 8)})',
      );
    }
  }

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

  // Getters
  List<BookingModel> get userBookings => _userBookings;
  List<BookingModel> get providerbookings => _providerBookings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BookingModel> get providerBookings => _providerBookings;

  // ✅ UPDATED: Status-specific getters (removed inProgress from active)
  List<BookingModel> get pendingBookings => _providerBookings
      .where((booking) => booking.status == BookingStatus.pending)
      .toList();

  List<BookingModel> get confirmedBookings => _providerBookings
      .where((booking) => booking.status == BookingStatus.confirmed)
      .toList();

  // ✅ CHANGED: Active bookings only include confirmed (no inProgress)
  List<BookingModel> get activeBookings => _providerBookings
      .where(
        (booking) =>
            booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.inProgress,
      )
      .toList();

  List<BookingModel> get completedBookings => _providerBookings
      .where((booking) => booking.status == BookingStatus.completed)
      .toList();

  List<BookingModel> get cancelledBookings => _providerBookings
      .where((booking) => booking.status == BookingStatus.cancelled)
      .toList();

  // ✅ UPDATED: Simplified status transitions (removed inProgress)
  bool _isValidStatusTransition(
    BookingStatus? currentStatus,
    BookingStatus newStatus,
  ) {
    if (currentStatus == null) return false;

    const validTransitions = {
      BookingStatus.pending: [BookingStatus.confirmed, BookingStatus.cancelled],
      BookingStatus.confirmed: [
        BookingStatus.inProgress, // ✅ Add this back
        BookingStatus.cancelled,
      ],
      BookingStatus.inProgress: [
        BookingStatus.completed,
        BookingStatus.cancelled,
      ],
      BookingStatus.completed: [BookingStatus.paid], // ✅ Allow paid transition
      BookingStatus.cancelled: [], // Final state
      BookingStatus.paid: [], // Final state
    };

    final allowed =
        validTransitions[currentStatus]?.contains(newStatus) ?? false;
    debugPrint('🔍 Status transition: $currentStatus → $newStatus = $allowed');
    return allowed;
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

  Future<void> refreshSpecificBooking(String bookingId) async {
    try {
      debugPrint(
        '🔄 [BOOKING PROVIDER] Refreshing specific booking: $bookingId',
      );

      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        final updatedBooking = BookingModel.fromFireStore(doc);

        // Update in provider bookings list
        final providerIndex = _providerBookings.indexWhere(
          (b) => b.id == bookingId,
        );
        if (providerIndex != -1) {
          _providerBookings[providerIndex] = updatedBooking;
          debugPrint(
            '✅ [BOOKING PROVIDER] Provider booking $bookingId refreshed',
          );
        }

        // Update in user bookings list
        final userIndex = _userBookings.indexWhere((b) => b.id == bookingId);
        if (userIndex != -1) {
          _userBookings[userIndex] = updatedBooking;
          debugPrint('✅ [BOOKING PROVIDER] User booking $bookingId refreshed');
        }

        notifyListeners();
        debugPrint(
          '✅ [BOOKING PROVIDER] Booking $bookingId refreshed with status: ${updatedBooking.status}',
        );
      }
    } catch (error) {
      debugPrint('❌ [BOOKING PROVIDER] Error refreshing booking: $error');
    }
  }

  void setProviderBookings(List<BookingModel> bookings) {
    _providerBookings = bookings;
    notifyListeners();
    debugPrint(
      '✅ [BOOKING PROVIDER] Provider bookings updated: ${bookings.length} bookings',
    );
  }

  Future<bool> cancelBooking(String bookingId, String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'cancelled',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'cancellationReason': 'Cancelled by user',
          });

      // Update local state
      final bookingIndex = _userBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _userBookings[bookingIndex] = _userBookings[bookingIndex].copyWith(
          status: BookingStatus.cancelled,
        );
      }

      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('❌ Error cancelling booking: $error');
      _setError('Failed to cancel booking: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add this method to BookingProvider class
  Future<void> loadProviderBookingsWithCustomerData(String providerId) async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint(
        '🔄 [PROVIDER] Loading bookings with customer data for: $providerId',
      );

      // Fetch bookings for this provider
      final bookingQuerySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      List<BookingModel> bookingsWithCustomerDetails = [];

      // Process each booking and fetch customer details
      for (var doc in bookingQuerySnapshot.docs) {
        BookingModel booking = BookingModel.fromFireStore(doc);

        // Fetch customer details for each booking
        final customerDetails = await _fetchCustomerDetails(booking.customerId);

        if (customerDetails != null) {
          booking = booking.copyWith(
            customerName: customerDetails['customerName'],
            customerPhone: customerDetails['customerPhone'],
            customerEmail: customerDetails['customerEmail'],
            customerAddressFromProfile: customerDetails['customerAddress'],
          );
        }

        bookingsWithCustomerDetails.add(booking);
      }

      _providerBookings = bookingsWithCustomerDetails;
      debugPrint(
        '✅ [PROVIDER] Loaded ${bookingsWithCustomerDetails.length} bookings with customer data',
      );
    } catch (e) {
      debugPrint('❌ [PROVIDER] Error loading bookings: $e');
      _setError('Failed to load bookings: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadUserBookingsWithProviderData(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint(
        '🔄 [CUSTOMER] Loading bookings with provider data for: $userId',
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      List<BookingModel> bookingsWithProviderDetails = [];

      // ✅ Process bookings sequentially to avoid overwhelming the system
      for (var doc in querySnapshot.docs) {
        try {
          BookingModel booking = BookingModel.fromFireStore(doc);
          debugPrint(
            '📋 [CUSTOMER] Processing booking: ${booking.serviceName} (Provider: ${booking.providerId})',
          );

          // ✅ CRITICAL: Always attempt to fetch provider details
          final providerDetails = await fetchProviderDetailsForCustomer(
            booking.providerId,
          );

          if (providerDetails != null &&
              providerDetails['providerName'] != 'Error Loading Provider') {
            booking = booking.copyWith(
              providerName: providerDetails['providerName'],
              providerPhone: providerDetails['providerPhone'],
              providerEmail: providerDetails['providerEmail'],
            );
            debugPrint(
              '✅ [CUSTOMER] Provider details loaded: ${providerDetails['providerName']}',
            );
          } else {
            debugPrint(
              '⚠️ [CUSTOMER] Provider details not found, using fallback',
            );
            booking = booking.copyWith(
              providerName: 'Provider information unavailable',
              providerPhone: '',
              providerEmail: '',
            );
          }

          bookingsWithProviderDetails.add(booking);
        } catch (e) {
          debugPrint('❌ [CUSTOMER] Error processing individual booking: $e');
          // Still add the booking even if provider details fail
          try {
            BookingModel booking = BookingModel.fromFireStore(doc);
            booking = booking.copyWith(
              providerName: 'Error loading provider details',
              providerPhone: '',
              providerEmail: '',
            );
            bookingsWithProviderDetails.add(booking);
          } catch (parseError) {
            debugPrint('❌ [CUSTOMER] Failed to parse booking: $parseError');
          }
        }
      }

      _userBookings = bookingsWithProviderDetails;
      debugPrint(
        '✅ [CUSTOMER] Loaded ${bookingsWithProviderDetails.length} bookings with provider data',
      );

      // Debug output
      for (var booking in bookingsWithProviderDetails.take(3)) {
        debugPrint(
          '   📋 ${booking.serviceName}: Provider = ${booking.providerName}',
        );
      }
    } catch (error) {
      debugPrint('❌ [CUSTOMER] Error loading user bookings: $error');
      _setError('Failed to load bookings: $error');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ✅ ENHANCED: Update existing _fetchCustomerDetails to handle Firestore better
  Future<Map<String, dynamic>?> _fetchCustomerDetails(String customerId) async {
    try {
      debugPrint('🔍 [PROVIDER] Fetching customer details for: $customerId');

      // Try Firebase Realtime Database first (where user data is actually stored)
      final userDoc = await FirebaseDatabase.instance
          .ref('users')
          .child(customerId)
          .get();

      if (userDoc.exists && userDoc.value != null) {
        final userData = Map<String, dynamic>.from(userDoc.value as Map);
        debugPrint(
          '✅ [PROVIDER] Customer found in Realtime DB: ${userData['name']}',
        );

        return {
          'customerName': userData['name']?.toString() ?? 'Unknown Customer',
          'customerPhone': userData['phone']?.toString() ?? '',
          'customerEmail': userData['email']?.toString() ?? '',
          'customerAddress': userData['address']?.toString() ?? '',
        };
      }

      // Fallback: Try Firestore users collection
      final firestoreDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();

      if (firestoreDoc.exists && firestoreDoc.data() != null) {
        final userData = firestoreDoc.data()!;
        debugPrint(
          '✅ [PROVIDER] Customer found in Firestore: ${userData['name']}',
        );

        return {
          'customerName': userData['name']?.toString() ?? 'Unknown Customer',
          'customerPhone':
              userData['phone']?.toString() ??
              userData['mobile']?.toString() ??
              '',
          'customerEmail': userData['email']?.toString() ?? '',
          'customerAddress': userData['address']?.toString() ?? '',
        };
      }

      debugPrint('❌ [PROVIDER] Customer not found: $customerId');
      return {
        'customerName': 'Customer Not Found',
        'customerPhone': '',
        'customerEmail': '',
        'customerAddress': '',
      };
    } catch (e) {
      debugPrint('❌ [PROVIDER] Error fetching customer: $e');
      return {
        'customerName': 'Error Loading Customer',
        'customerPhone': '',
        'customerEmail': '',
        'customerAddress': '',
      };
    }
  }

  // In BookingProvider class - Add these public helper methods
  Future<Map<String, dynamic>?> fetchCustomerDetailsForProvider(
    String customerId,
  ) async {
    return await _fetchCustomerDetails(customerId);
  }

  Future<Map<String, dynamic>?> fetchProviderDetailsForCustomer(
    String providerId,
  ) async {
    try {
      debugPrint('🔍 [CUSTOMER] Fetching provider details for: $providerId');

      // First try providers collection (preferred for providers)
      try {
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();

        if (providerDoc.exists && providerDoc.data() != null) {
          final providerData = providerDoc.data()!;
          debugPrint('✅ [CUSTOMER] Provider found in providers collection');

          return {
            'providerName':
                providerData['businessName']?.toString() ?? 'Unknown Provider',
            'providerPhone':
                providerData['mobileNumber']?.toString() ??
                providerData['phone']?.toString() ??
                '',
            'providerEmail': providerData['email']?.toString() ?? '',
            'providerAddress': providerData['address']?.toString() ?? '',
          };
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER] Firestore providers error: $e');
      }

      // Fallback to Realtime Database
      try {
        final userDoc = await FirebaseDatabase.instance
            .ref('users')
            .child(providerId)
            .get();

        if (userDoc.exists && userDoc.value != null) {
          final userData = Map<String, dynamic>.from(userDoc.value as Map);
          debugPrint('✅ [CUSTOMER] Provider found in Realtime DB');

          return {
            'providerName':
                userData['businessName']?.toString() ??
                userData['name']?.toString() ??
                'Unknown Provider',
            'providerPhone': userData['phone']?.toString() ?? '',
            'providerEmail': userData['email']?.toString() ?? '',
            'providerAddress': userData['address']?.toString() ?? '',
          };
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER] Realtime DB error: $e');
      }

      // Last fallback to users collection
      try {
        final userFirestoreDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (userFirestoreDoc.exists && userFirestoreDoc.data() != null) {
          final userData = userFirestoreDoc.data()!;
          debugPrint('✅ [CUSTOMER] Provider found in users collection');

          return {
            'providerName':
                userData['businessName']?.toString() ??
                userData['name']?.toString() ??
                'Unknown Provider',
            'providerPhone': userData['phone']?.toString() ?? '',
            'providerEmail': userData['email']?.toString() ?? '',
            'providerAddress': userData['address']?.toString() ?? '',
          };
        }
      } catch (e) {
        debugPrint('⚠️ [CUSTOMER] Firestore users error: $e');
      }

      debugPrint(
        '❌ [CUSTOMER] Provider not found in any collection: $providerId',
      );
      return {
        'providerName': 'Provider Not Available',
        'providerPhone': '',
        'providerEmail': '',
        'providerAddress': '',
      };
    } catch (e) {
      debugPrint('❌ [CUSTOMER] Error fetching provider: $e');
      return {
        'providerName': 'Error Loading Provider',
        'providerPhone': '',
        'providerEmail': '',
        'providerAddress': '',
      };
    }
  }

  Future<Map<String, dynamic>?> _fetchProviderDetails(String providerId) async {
    return await fetchProviderDetailsForCustomer(providerId);
  }

  Future<void> loadServiceBookings(String serviceId) async {
    try {
      debugPrint('🔄 Loading bookings for service: $serviceId');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('serviceId', isEqualTo: serviceId)
          .get();

      final serviceBookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      debugPrint('✅ Loaded ${serviceBookings.length} bookings for service');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading service bookings: $e');
    }
  }

  BookingModel? getUserBookingForService(String userId, String serviceId) {
    try {
      return userBookings.firstWhere(
        (booking) =>
            booking.customerId == userId && booking.serviceId == serviceId,
      );
    } catch (e) {
      return null; // No booking found
    }
  }

  List<BookingModel> getBookingsByStatus(BookingStatus status) {
    return _providerBookings
        .where((booking) => booking.status == status)
        .toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ✅ UPDATED: Enhanced updateBookingStatus without inProgress
  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
    String currentUserId,
  ) async {
    if (isBookingLocked(bookingId)) {
      debugPrint(
        '🔒 [CONFLICT PREVENTION] Booking locked for OTP verification: $bookingId',
      );
      return false;
    }

    if (_isUpdatingStatus) {
      debugPrint('⚠️ [CONFLICT PREVENTION] Update already in progress');
      return false;
    }

    _isUpdatingStatus = true;

    try {
      debugPrint(
        '🔄 [BOOKING PROVIDER] Starting atomic update for: $bookingId',
      );
      debugPrint('   - Target Status: $newStatus');
      debugPrint('   - Provider ID: $currentUserId');

      bool success = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final bookingRef = FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId);
        final bookingDoc = await transaction.get(bookingRef);

        if (!bookingDoc.exists) {
          throw Exception('Booking document not found');
        }

        final currentData = bookingDoc.data()!;
        final currentStatus = bookingStatusFromString(currentData['status']);

        debugPrint('   - Current DB Status: $currentStatus');

        // ✅ CRITICAL: Validate status transition
        if (!_isValidStatusTransition(currentStatus, newStatus)) {
          throw Exception('Invalid transition: $currentStatus → $newStatus');
        }

        // ✅ CRITICAL: Use live date/time for all updates
        final DateTime liveDateTime = DateTime.now();

        final updateData = {
          'status': newStatus.toString().split('.').last,
          'lastUpdatedBy': 'provider_$currentUserId',
          'updatedAt': Timestamp.fromDate(liveDateTime),
          'lastStatusChange': Timestamp.fromDate(liveDateTime),
        };

        // ✅ ENHANCED: Set completion date to exact live date/time
        if (newStatus == BookingStatus.completed) {
          final DateTime completionDateTime = DateTime.now();
          updateData['completedAt'] = Timestamp.fromDate(completionDateTime);
          debugPrint(
            '✅ Setting completion date to live time: $completionDateTime',
          );
        }

        debugPrint('   - Update Data: $updateData');
        transaction.update(bookingRef, updateData);
        success = true;
      });

      if (success) {
        debugPrint('✅ [BOOKING PROVIDER] Status updated successfully');

        // Update local state immediately
        final bookingIndex = _providerBookings.indexWhere(
          (b) => b.id == bookingId,
        );
        if (bookingIndex != -1) {
          final updatedBooking = _providerBookings[bookingIndex].copyWith(
            status: newStatus,
            completedAt: newStatus == BookingStatus.completed
                ? DateTime.now()
                : null,
          );

          final updatedBookings = List<BookingModel>.from(_providerBookings);
          updatedBookings[bookingIndex] = updatedBooking;
          _providerBookings = updatedBookings;

          notifyListeners();
        }

        // ✅ UPDATED: Send notification to customer using new method
        if (success &&
            (newStatus == BookingStatus.confirmed ||
                newStatus == BookingStatus.completed)) {
          final bookingDoc = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

          if (bookingDoc.exists) {
            final data = bookingDoc.data()!;
            final customerId = data['customerId'] as String?;
            final serviceName =
                data['serviceName'] as String? ?? 'Your service';

            if (customerId != null) {
              String statusText = newStatus == BookingStatus.confirmed
                  ? 'confirmed'
                  : 'completed';

              // ✅ Create notification document in Firestore for customer
              await FirebaseFirestore.instance.collection('notifications').add({
                'targetUserId': customerId,
                'title': newStatus == BookingStatus.confirmed
                    ? 'Booking Confirmed! ✅'
                    : 'Service Completed! 🎉',
                'body': newStatus == BookingStatus.confirmed
                    ? 'Your $serviceName booking has been accepted'
                    : 'Your $serviceName service is now complete',
                'data': {
                  'type': 'status_update',
                  'bookingId': bookingId,
                  'status': statusText,
                },
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });

              debugPrint('✅ Status change notification created for customer');
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 1000));
        return true;
      }

      return false;
    } catch (error) {
      debugPrint('❌ [BOOKING PROVIDER] Failed: $error');
      return false;
    } finally {
      _isUpdatingStatus = false;
    }
  }

  // Add these fields to the top of BookingProvider class
  final Set<String> _systemUpdatedBookings = {};

  // Add these methods to BookingProvider
  void markBookingAsSystemUpdated(String bookingId) {
    _systemUpdatedBookings.add(bookingId);
    debugPrint(
      '🔒 [SYSTEM PROTECTION] Marking booking as system updated: $bookingId',
    );

    // Auto-remove after 30 seconds
    Timer(const Duration(seconds: 30), () {
      _systemUpdatedBookings.remove(bookingId);
      debugPrint(
        '🔓 [SYSTEM PROTECTION] Auto-removed system protection: $bookingId',
      );
    });
  }

  bool isBookingSystemUpdated(String bookingId) {
    return _systemUpdatedBookings.contains(bookingId);
  }

  Future<bool> bookServiceWithNotification({
    required String serviceId,
    required String providerId,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required DateTime scheduledDate,
    required String serviceTitle,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create booking in Firestore
      DocumentReference bookingRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add({
            'serviceId': serviceId,
            'providerId': providerId,
            'customerId': customerId,
            'customerName': customerName,
            'customerPhone': customerPhone,
            'scheduledDate': Timestamp.fromDate(scheduledDate),
            'serviceTitle': serviceTitle,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            ...?additionalData,
          });

      debugPrint('✅ Booking created: ${bookingRef.id}');

      // Notify provider immediately
      await RealtimeNotificationService.instance.notifyProviderOfNewBooking(
        bookingId: bookingRef.id,
        providerId: providerId,
        customerName: customerName,
        serviceTitle: serviceTitle,
        scheduledDate: scheduledDate,
        customerPhone: customerPhone,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error creating booking: $e');
      return false;
    }
  }

  // ✅ UPDATED: Customer booking status update for payment completion
  Future<bool> updateCustomerBookingStatus(
    String bookingId,
    BookingStatus newStatus,
    String customerId,
  ) async {
    try {
      debugPrint('🔄 [CUSTOMER] Updating booking status to: $newStatus');

      // ✅ CRITICAL: Use live date/time
      final DateTime liveDateTime = DateTime.now();

      final updateData = {
        'status': newStatus.toString().split('.').last,
        'lastUpdatedBy': 'customer_$customerId',
        'updatedAt': Timestamp.fromDate(liveDateTime),
      };

      // ✅ ENHANCED: Set completion date to live time for customer updates
      if (newStatus == BookingStatus.completed) {
        final DateTime completionDateTime =
            DateTime.now(); // Live completion time
        updateData['completedAt'] = Timestamp.fromDate(completionDateTime);

        debugPrint(
          '✅ [CUSTOMER] Setting completion date to live time: $completionDateTime',
        );
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);

      // Update local state
      final bookingIndex = _userBookings.indexWhere((b) => b.id == bookingId);
      if (bookingIndex != -1) {
        _userBookings[bookingIndex] = _userBookings[bookingIndex].copyWith(
          status: newStatus,
          completedAt: newStatus == BookingStatus.completed
              ? DateTime.now() // ✅ Live completion date in local state
              : null,
        );
        notifyListeners();
      }

      return true;
    } catch (error) {
      debugPrint('❌ [CUSTOMER] Error updating status: $error');
      return false;
    }
  }

  // Rest of your existing methods remain the same...
  Future<void> initializeProvider(String providerId) async {
    if (_currentProviderId == providerId &&
        _providerBookingsSubscription != null) {
      debugPrint('🔄 Provider already initialized for $providerId');
      return;
    }

    debugPrint('🔄 [BOOKING PROVIDER] Initializing for provider: $providerId');
    _currentProviderId = providerId;

    await _cancelAllListeners();

    // ✅ Use the new method that loads customer data
    await loadProviderBookingsWithCustomerData(providerId);

    // ✅ Setup real-time listener (this method should now exist)
    _setupSingleRealTimeListener(providerId);
  }

  // In BookingProvider - Enhanced real-time listener
  void _setupSingleRealTimeListener(String providerId) {
    debugPrint('🔄 Setting up enhanced real-time listener for: $providerId');

    _providerBookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint(
              '🔔 [REAL-TIME] Received snapshot with ${snapshot.docs.length} documents',
            );

            // ✅ CRITICAL: Check for system-protected bookings
            List<BookingModel> bookingsWithCustomerDetails = [];

            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final bookingId = doc.id;
                final status = data['status']?.toString() ?? 'pending';
                final lastUpdatedBy = data['lastUpdatedBy']?.toString() ?? '';
                final systemProtected = data['systemProtected'] ?? false;
                final systemProtectedUntil =
                    data['systemProtectedUntil'] as Timestamp?;

                debugPrint('🔍 [REAL-TIME] Processing booking $bookingId:');
                debugPrint('   - Status: $status');
                debugPrint('   - LastUpdatedBy: $lastUpdatedBy');
                debugPrint('   - SystemProtected: $systemProtected');

                // ✅ CRITICAL: Skip processing if system protected and still valid
                if (systemProtected && systemProtectedUntil != null) {
                  final protectedUntil = systemProtectedUntil.toDate();
                  if (DateTime.now().isBefore(protectedUntil)) {
                    debugPrint(
                      '🛡️ [REAL-TIME] Skipping system-protected booking: $bookingId',
                    );

                    // Create booking model from existing data without overwriting
                    BookingModel booking = BookingModel.fromFireStore(doc);
                    final customerDetails = await _fetchCustomerDetails(
                      booking.customerId,
                    );
                    if (customerDetails != null) {
                      booking = booking.copyWith(
                        customerName: customerDetails['customerName'],
                        customerPhone: customerDetails['customerPhone'],
                        customerEmail: customerDetails['customerEmail'],
                        customerAddressFromProfile:
                            customerDetails['customerAddress'],
                      );
                    }
                    bookingsWithCustomerDetails.add(booking);
                    continue;
                  }
                }

                // ✅ CRITICAL: Also check local protection
                if (isBookingSystemUpdated(bookingId)) {
                  debugPrint(
                    '🛡️ [REAL-TIME] Skipping locally protected booking: $bookingId',
                  );

                  // Use existing local data instead of snapshot data
                  final existingBooking = _providerBookings
                      .where((b) => b.id == bookingId)
                      .firstOrNull;
                  if (existingBooking != null) {
                    bookingsWithCustomerDetails.add(existingBooking);
                    continue;
                  }
                }

                // Normal processing for non-protected bookings
                BookingModel booking = BookingModel.fromFireStore(doc);
                final customerDetails = await _fetchCustomerDetails(
                  booking.customerId,
                );
                if (customerDetails != null) {
                  booking = booking.copyWith(
                    customerName: customerDetails['customerName'],
                    customerPhone: customerDetails['customerPhone'],
                    customerEmail: customerDetails['customerEmail'],
                    customerAddressFromProfile:
                        customerDetails['customerAddress'],
                  );
                }
                bookingsWithCustomerDetails.add(booking);
              } catch (e) {
                debugPrint('❌ [REAL-TIME] Error processing booking: $e');
              }
            }

            _providerBookings = bookingsWithCustomerDetails;
            notifyListeners();

            // ✅ DEBUG: Log final status distribution
            debugPrint('✅ [REAL-TIME] Final booking states:');
            for (var booking in bookingsWithCustomerDetails.take(5)) {
              debugPrint('   - ${booking.serviceName}: ${booking.status}');
            }

            final inProgressCount = bookingsWithCustomerDetails
                .where((b) => b.status == BookingStatus.inProgress)
                .length;
            debugPrint('📊 [REAL-TIME] InProgress bookings: $inProgressCount');
          },
          onError: (error) {
            debugPrint('❌ [REAL-TIME] Error: $error');
          },
        );
  }

  // Add this method to BookingProvider
  Future<void> unlockBookingStatus(String bookingId) async {
    try {
      await Future.delayed(
        const Duration(seconds: 5),
      ); // Wait for OTP verification to settle

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'statusLocked': false,
            'statusLockReason': null,
            'statusLockedAt': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      debugPrint('✅ Booking status unlocked: $bookingId');
    } catch (e) {
      debugPrint('❌ Error unlocking booking status: $e');
    }
  }

  // Add these fields to BookingProvider class
  final Set<String> _lockedBookings = {};

  // Add this method to BookingProvider
  void lockBookingForOTP(String bookingId) {
    _lockedBookings.add(bookingId);
    debugPrint('🔒 [BOOKING LOCK] Locked booking for OTP: $bookingId');
  }

  void unlockBookingFromOTP(String bookingId) {
    _lockedBookings.remove(bookingId);
    debugPrint('🔓 [BOOKING LOCK] Unlocked booking from OTP: $bookingId');
  }

  bool isBookingLocked(String bookingId) {
    return _lockedBookings.contains(bookingId);
  }

  // Add this method to BookingProvider
  void pauseRealTimeListener() {
    debugPrint(
      '⏸️ [BOOKING PROVIDER] Pausing real-time listener for OTP verification',
    );
    _providerBookingsSubscription?.pause();
  }

  void resumeRealTimeListener() {
    debugPrint('▶️ [BOOKING PROVIDER] Resuming real-time listener');
    _providerBookingsSubscription?.resume();
  }

  void debugStatusAfterOTP(String operation) {
    debugPrint('🔍 [$operation] Status check:');
    debugPrint('   - _isUpdatingStatus: $_isUpdatingStatus');
    debugPrint('   - Total bookings: ${_providerBookings.length}');

    for (var booking in _providerBookings) {
      debugPrint(
        '   - ${booking.serviceName}: ${booking.status} (${booking.id.substring(0, 8)})',
      );
    }

    debugPrint(
      '   - InProgress count: ${_providerBookings.where((b) => b.status == BookingStatus.inProgress).length}',
    );
    debugPrint('   - Active tab count: ${activeBookings.length}');
  }

  Future<void> loadProviderBookings(String providerId) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .get();

      final bookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      _providerBookings = bookings;
      debugPrint('✅ Loaded ${bookings.length} provider bookings');
    } catch (error) {
      debugPrint('❌ Error loading provider bookings: $error');
      _setError('Failed to load bookings: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUserBookings(String userId) async {
    try {
      _setLoading(true);
      _setError(null);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final bookings = querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();

      _userBookings = bookings;
      debugPrint('✅ Loaded ${bookings.length} user bookings');
    } catch (error) {
      debugPrint('❌ Error loading user bookings: $error');
      _setError('Failed to load bookings: $error');
    } finally {
      _setLoading(false);
    }
  }

  void updateUserBookings(List<BookingModel> bookings) {
    _userBookings = bookings;
    debugPrint('✅ Updated user bookings: ${_userBookings.length}');
    notifyListeners();
  }

  Future<void> _cancelAllListeners() async {
    _providerBookingsSubscription?.cancel();
    _providerBookingsSubscription = null;
    debugPrint('🛑 All booking listeners cancelled');
  }

  void disposeProviderListener() {
    _cancelAllListeners();
    _currentProviderId = null;
    debugPrint('🛑 Provider booking listener disposed');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAllListeners();
    super.dispose();
  }

  // Add other existing methods like createBooking, etc. (keep them unchanged)
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
    required String customerName, // ✅ NEW: Required parameter
    required String customerPhone, // ✅ NEW: Required parameter
    required String customerEmail, // ✅ NEW: Required parameter
    DateTime? selectedDate,
    DateTime? bookedDate,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await OTPService.instance.createCustomerOTP(customerId);

      final booking = BookingModel(
        id: '',
        customerId: customerId,
        providerId: providerId,
        serviceId: service.id,
        serviceName: service.name,
        description: description,
        scheduledDateTime: scheduledDateTime,
        customerAddress: customerAddress,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
        totalAmount: totalAmount,
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
        selectedDate: selectedDate,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add(booking.toFireStore());

      final savedBooking = booking.copyWith(id: docRef.id);

      // ✅ FIXED: No more context dependency
      await _markServiceAsBooked(
        service.id,
        customerId,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      await AdService.instance.showRewarded(
        onReward: (amount) {
          debugPrint('🎉 Customer earned reward: $amount');
        },
      );

      // ✅ CRITICAL: Ensure provider has FCM token before sending notification
      await _ensureProviderHasFCMToken(providerId);

      // ✅ FIXED: Use passed parameters instead of authProvider
      await NotificationService.instance.notifyProviderOfBooking(
        providerId: providerId,
        serviceName: service.name,
        customerName: customerName,
        bookingId: savedBooking.id,
      );

      debugPrint('✅ Customer booking rewards and notifications sent');

      _userBookings.add(savedBooking);
      notifyListeners();

      return savedBooking;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ ADD these helper methods to your BookingProvider class
  Future<void> _markServiceAsBooked(
    String serviceId,
    String userId, {
    String? customerName,
    String? customerPhone,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .update({
            'isBooked': true,
            'bookedByUserId': userId,
            'bookedAt': FieldValue.serverTimestamp(),
            'availability': 'booked',
            'customerName': customerName,
            'customerPhone': customerPhone,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      debugPrint('✅ Service marked as booked successfully');
    } catch (e) {
      debugPrint('❌ Error marking service as booked: $e');
    }
  }

  Future<void> _ensureProviderHasFCMToken(String providerId) async {
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();

      if (!providerDoc.exists || providerDoc.data()?['fcmToken'] == null) {
        final freshToken = await FCMTokenManager.getToken();
        if (freshToken != null) {
          await FirebaseFirestore.instance
              .collection('providers')
              .doc(providerId)
              .set({
                'fcmToken': freshToken,
                'lastTokenUpdate': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          debugPrint('✅ Fresh FCM token saved for provider');
        }
      }
    } catch (e) {
      debugPrint('❌ Error ensuring provider FCM token: $e');
    }
  }

  Future<bool> updateBookingStatusWithProgress(
    String bookingId,
    BookingStatus newStatus,
    String providerId, {
    DateTime? workStartTime,
    DateTime? workEndTime,
    double? workProgress,
  }) async {
    try {
      debugPrint('🔄 Updating booking with progress: $bookingId');

      final updateData = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'lastUpdatedBy': 'provider_$providerId',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (workStartTime != null) {
        updateData['workStartTime'] = Timestamp.fromDate(workStartTime);
        updateData['isWorkInProgress'] = true;
        updateData['workProgress'] = 0.1; // Initial progress
      }

      if (workEndTime != null) {
        updateData['workEndTime'] = Timestamp.fromDate(workEndTime);
        updateData['isWorkInProgress'] = false;
        updateData['workProgress'] = 1.0; // Complete progress
      }

      if (workProgress != null) {
        updateData['workProgress'] = workProgress;
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);

      await refreshSpecificBooking(bookingId);

      await loadProviderBookingsWithCustomerData(providerId);

      // Update local state
      final bookingIndex = _providerBookings.indexWhere(
        (b) => b.id == bookingId,
      );
      if (bookingIndex != -1) {
        _providerBookings[bookingIndex] = _providerBookings[bookingIndex]
            .copyWith(
              status: newStatus,
              workStartTime: workStartTime,
              workEndTime: workEndTime,
              workProgress: workProgress,
              isWorkInProgress: workStartTime != null && workEndTime == null,
            );
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error updating booking with progress: $e');
      return false;
    }
  }

  // ✅ NEW: Update work progress
  Future<void> updateWorkProgress(String bookingId, double progress) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': progress,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

      // Update local state
      final bookingIndex = _providerBookings.indexWhere(
        (b) => b.id == bookingId,
      );
      if (bookingIndex != -1) {
        _providerBookings[bookingIndex] = _providerBookings[bookingIndex]
            .copyWith(workProgress: progress);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating work progress: $e');
    }
  }
}
