import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';
import '../../core/services/firebase_service.dart';

class BookingRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;
  static const double _developerCommissionRate = 0.10;

  final CollectionReference bookingsCollection = FirebaseFirestore.instance
      .collection('bookings');

  Future<void> createBooking(BookingModel booking) async {
    final developerCommission =
        (booking.totalAmount * _developerCommissionRate);
    final providerAmount = booking.totalAmount - developerCommission;
    try {
      final bookingWithCommission = BookingModel(
        id: booking.id,
        customerId: booking.customerId,
        providerId: booking.providerId,
        serviceId: booking.serviceId,
        serviceName: booking.serviceName,
        scheduledDateTime: booking.scheduledDateTime,
        description: booking.description,
        totalAmount: booking.totalAmount,
        status: booking.status,
        customerAddress: booking.customerAddress,
        createdAt: booking.createdAt,
        completedAt: booking.completedAt,
        // Add commission fields here
        developerCommission: developerCommission,
        providerAmount: providerAmount,
      );

      await bookingsCollection
          .doc(bookingWithCommission.id)
          .set(bookingWithCommission.toFireStore());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBookingPayment(
    String bookingId,
    double totalPaidAmount,
  ) async {
    final developerCommission = totalPaidAmount * _developerCommissionRate;
    final providerAmount = totalPaidAmount - developerCommission;

    await bookingsCollection.doc(bookingId).update({
      'totalAmount': totalPaidAmount,
      'developerCommission': developerCommission,
      'providerAmount': providerAmount,
    });
  }

  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc = await _firebaseService.getDocument('bookings', bookingId);
      if (doc.exists) {
        return BookingModel.fromFireStore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('customerId', isEqualTo: userId)
            .orderBy('createdAt', descending: true),
      );

      return querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<BookingModel>> getProviderBookings(String providerId) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('providerId', isEqualTo: providerId)
            .orderBy('createdAt', descending: true),
      );

      return querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.toString().split('.').last,
      };

      if (status == BookingStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firebaseService.updateDocument('bookings', bookingId, updateData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBooking(BookingModel booking) async {
    try {
      await _firebaseService.updateDocument(
        'bookings',
        booking.id,
        booking.toFireStore(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _firebaseService.updateDocument('bookings', bookingId, {
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _firebaseService
        .getCollectionStream(
          'bookings',
          queryBuilder: (query) => query
              .where('customerId', isEqualTo: userId)
              .orderBy('createdAt', descending: true),
        )
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFireStore(doc))
              .toList(),
        );
  }

  Stream<List<BookingModel>> getProviderBookingsStream(String providerId) {
    return _firebaseService
        .getCollectionStream(
          'bookings',
          queryBuilder: (query) => query
              .where('providerId', isEqualTo: providerId)
              .orderBy('createdAt', descending: true),
        )
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromFireStore(doc))
              .toList(),
        );
  }

  Future<List<BookingModel>> getBookingsByStatus(BookingStatus status) async {
    try {
      final querySnapshot = await _firebaseService.getCollection(
        'bookings',
        queryBuilder: (query) => query
            .where('status', isEqualTo: status.toString().split('.').last)
            .orderBy('createdAt', descending: true),
      );

      return querySnapshot.docs
          .map((doc) => BookingModel.fromFireStore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
