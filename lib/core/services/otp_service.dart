import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPService {
  static OTPService? _instance;
  static OTPService get instance => _instance ??= OTPService._();

  OTPService._();

  // Generate 4-digit OTP
  String generateOTP() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString(); // 4-digit OTP
  }

  // ✅ MIGRATED: Create customer-based OTP using Firestore
  Future<String> createCustomerOTP(String customerId) async {
    try {
      // Check if customer already has an active OTP
      final existingOTP = await getCustomerOTP(customerId);
      if (existingOTP != null) {
        return existingOTP;
      }

      final otp = generateOTP();

      // ✅ MIGRATED: Store in Firestore instead of Realtime Database
      final otpData = {
        'code': otp,
        'customerId': customerId,
        'createdAt':
            FieldValue.serverTimestamp(), // Changed from ServerValue.timestamp
        'isActive': true,
        'lastUsed': null,
      };

      await FirebaseFirestore.instance
          .collection('customer_otps') // Changed from ref() to collection()
          .doc(customerId) // Changed from child() to doc()
          .set(otpData); // Changed from set() to set()

      return otp;
    } catch (e) {
      rethrow;
    }
  }

  // ✅ MIGRATED: Get customer OTP from Firestore
  Future<String?> getCustomerOTP(String customerId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('customer_otps')
          .doc(customerId)
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        return null;
      }

      final data = docSnapshot.data()!;
      final isActive = data['isActive'] ?? false;

      if (!isActive) {
        return null;
      }

      final code = data['code'] as String?;
      return code;
    } catch (e) {
      // Handle errors
      return null;
    }
  }

  // ✅ MIGRATED: Verify customer OTP and start work progress using Firestore
  Future<bool> verifyCustomerOTPAndStartWork(
    String customerId,
    String enteredOTP,
    String bookingId,
  ) async {
    try {
      final storedOTP = await getCustomerOTP(customerId);
      if (storedOTP == null) {
        return false;
      }

      if (storedOTP == enteredOTP) {
        // ✅ MIGRATED: Update last used timestamp in Firestore
        await FirebaseFirestore.instance
            .collection('customer_otps')
            .doc(customerId)
            .update({
              'lastUsed': FieldValue.serverTimestamp(),
              'lastUsedForBooking': bookingId,
            });

        // ✅ Start work progress tracking
        await _startWorkProgress(bookingId);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // ✅ Enhanced: Start work progress tracking
  Future<void> _startWorkProgress(String bookingId) async {
    try {
      final now = DateTime.now();

      // Update booking with work start time and initial progress
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'inProgress',
            'workStartTime': Timestamp.fromDate(now),
            'workProgress': 0.0,
            'isWorkInProgress': true,
            'progressUpdatedAt': Timestamp.fromDate(now),
          });
    } catch (e) {
      // Handle errors
    }
  }

  // ✅ MIGRATED: Create booking-specific OTP in Firestore
  Future<String> createOTPForBooking(String bookingId) async {
    try {
      final booking = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (booking.exists) {
        final customerId = booking.data()!['customerId'] as String;

        // Create customer OTP first
        final otpCode = await createCustomerOTP(customerId);

        // Also create a booking-specific OTP record for easy provider access
        await FirebaseFirestore.instance
            .collection('booking_otps')
            .doc(bookingId)
            .set({
              'bookingId': bookingId,
              'customerId': customerId,
              'otpCode': otpCode,
              'isVerified': false,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(hours: 24)),
              ),
            });

        return otpCode;
      }

      throw Exception('Booking not found');
    } catch (e) {
      rethrow;
    }
  }

  // ✅ MIGRATED: Get OTP for booking from Firestore
  Future<String?> getOTPForBooking(String bookingId) async {
    try {
      // First try to get from booking_otps collection
      final bookingOtpDoc = await FirebaseFirestore.instance
          .collection('booking_otps')
          .doc(bookingId)
          .get();

      if (bookingOtpDoc.exists) {
        return bookingOtpDoc.data()?['otpCode'] as String?;
      }

      // Fallback to customer_otps collection
      final booking = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (booking.exists) {
        final customerId = booking.data()!['customerId'] as String;
        return getCustomerOTP(customerId);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ FIXED: Verify OTP and transition to inProgress
  Future<bool> verifyOTP(String bookingId, String enteredOTP) async {
    try {
      final booking = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!booking.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = booking.data()!;
      final customerId = bookingData['customerId'] as String;

      final storedOTP = await getCustomerOTP(customerId);
      if (storedOTP == null) {
        throw Exception('No OTP found for customer');
      }

      if (storedOTP != enteredOTP.trim()) {
        throw Exception('Invalid OTP');
      }

      // ✅ CRITICAL: Multi-verification update with protection
      try {
        // First, use a transaction to ensure atomicity
        bool transactionSuccess = false;

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final bookingRef = FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId);

          final freshBookingDoc = await transaction.get(bookingRef);
          if (!freshBookingDoc.exists) {
            throw Exception('Booking disappeared during transaction');
          }

          final freshData = freshBookingDoc.data()!;
          final freshStatus = freshData['status'] as String?;

          if (freshStatus != 'confirmed') {
            throw Exception(
              'Booking status changed during verification: $freshStatus',
            );
          }

          // ✅ CRITICAL: Comprehensive update with protection markers
          transaction.update(bookingRef, {
            'status': 'inProgress',
            'workStartTime': FieldValue.serverTimestamp(),
            'isWorkInProgress': true,
            'workProgress': 0.1,
            'progressUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': 'system_otp_verification',
            'updatedAt': FieldValue.serverTimestamp(),
            'otpVerified': true,
            'otpVerifiedAt': FieldValue.serverTimestamp(),
            // ✅ PROTECTION: Add unique markers to prevent overwrites
            'otpTransactionId':
                '${bookingId}_${DateTime.now().millisecondsSinceEpoch}',
            'systemProtected': true,
            'systemProtectedUntil': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 5)),
            ),
          });

          transactionSuccess = true;
        });

        if (!transactionSuccess) {
          return false;
        }

        // ✅ VERIFICATION: Wait and verify the update persisted
        for (int i = 0; i < 10; i++) {
          await Future.delayed(Duration(milliseconds: 500 * (i + 1)));

          final verificationDoc = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

          if (verificationDoc.exists) {
            final verifyData = verificationDoc.data()!;
            final finalStatus = verifyData['status'] as String?;
            final lastUpdatedBy = verifyData['lastUpdatedBy'] as String?;
            final otpTransactionId = verifyData['otpTransactionId'] as String?;

            if (finalStatus == 'inProgress' &&
                lastUpdatedBy == 'system_otp_verification' &&
                otpTransactionId != null) {
              return true;
            } else if (finalStatus != 'inProgress') {
              // Try one more direct update
              await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(bookingId)
                  .update({
                    'status': 'inProgress',
                    'lastUpdatedBy': 'system_otp_verification_retry',
                    'updatedAt': FieldValue.serverTimestamp(),
                    'forceProtected': true,
                  });
            }
          }
        }

        return false;
      } catch (updateError) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
