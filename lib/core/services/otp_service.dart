// lib/core/services/otp_service.dart (Updated for Firestore)
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      debugPrint('🔑 Creating customer OTP for: $customerId');

      // Check if customer already has an active OTP
      final existingOTP = await getCustomerOTP(customerId);
      if (existingOTP != null) {
        debugPrint('✅ Customer already has OTP: $existingOTP');
        return existingOTP;
      }

      final otp = generateOTP();
      final now = DateTime.now();

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

      debugPrint('✅ Customer OTP created successfully in Firestore: $otp');
      return otp;
    } catch (e) {
      debugPrint('❌ Error creating customer OTP in Firestore: $e');
      rethrow;
    }
  }

  // ✅ MIGRATED: Get customer OTP from Firestore
  Future<String?> getCustomerOTP(String customerId) async {
    try {
      debugPrint('🔍 Getting customer OTP from Firestore for: $customerId');

      final docSnapshot = await FirebaseFirestore.instance
          .collection('customer_otps')
          .doc(customerId)
          .get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        debugPrint('❌ No OTP found in Firestore for customer: $customerId');
        return null;
      }

      final data = docSnapshot.data()!;
      final isActive = data['isActive'] ?? false;

      if (!isActive) {
        debugPrint('⚠️ Customer OTP is inactive: $customerId');
        return null;
      }

      final code = data['code'] as String?;
      debugPrint('✅ Customer OTP retrieved from Firestore: $code');
      return code;
    } catch (e) {
      debugPrint('❌ Error getting customer OTP from Firestore: $e');
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
      debugPrint('🔐 Verifying customer OTP in Firestore for: $customerId');

      final storedOTP = await getCustomerOTP(customerId);
      if (storedOTP == null) {
        debugPrint('❌ No stored OTP found for customer in Firestore');
        return false;
      }

      if (storedOTP == enteredOTP) {
        debugPrint('✅ Customer OTP verified successfully in Firestore');

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
        debugPrint('❌ Invalid customer OTP entered');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error verifying customer OTP in Firestore: $e');
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

      debugPrint('✅ Work progress started for booking: $bookingId');
    } catch (e) {
      debugPrint('❌ Error starting work progress: $e');
    }
  }

  // ✅ MIGRATED: Create booking-specific OTP in Firestore
  Future<String> createOTPForBooking(String bookingId) async {
    try {
      debugPrint('🔑 Creating OTP for booking in Firestore: $bookingId');

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

        debugPrint('✅ Booking OTP created in Firestore: $otpCode');
        return otpCode;
      }

      throw Exception('Booking not found');
    } catch (e) {
      debugPrint('❌ Error creating OTP for booking in Firestore: $e');
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
      debugPrint('❌ Error getting OTP for booking from Firestore: $e');
      return null;
    }
  }

  // ✅ FIXED: Verify OTP and transition to inProgress
  Future<bool> verifyOTP(String bookingId, String enteredOTP) async {
    try {
      debugPrint(
        '🔐 [OTP VERIFICATION] Starting verification for booking: $bookingId',
      );

      final booking = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!booking.exists) {
        debugPrint('❌ [OTP VERIFICATION] Booking document not found');
        throw Exception('Booking not found');
      }

      final bookingData = booking.data()!;
      final customerId = bookingData['customerId'] as String;
      final currentStatus = bookingData['status'] as String?;

      debugPrint(
        '🔍 [OTP VERIFICATION] Current booking status: $currentStatus',
      );

      final storedOTP = await getCustomerOTP(customerId);
      if (storedOTP == null) {
        debugPrint(
          '❌ [OTP VERIFICATION] No OTP found for customer: $customerId',
        );
        throw Exception('No OTP found for customer');
      }

      debugPrint(
        '🔍 [OTP VERIFICATION] Stored OTP: $storedOTP, Entered: $enteredOTP',
      );

      if (storedOTP != enteredOTP.trim()) {
        debugPrint('❌ [OTP VERIFICATION] OTP mismatch');
        throw Exception('Invalid OTP');
      }

      // ✅ CRITICAL: Multi-verification update with protection
      try {
        debugPrint('🔄 [OTP VERIFICATION] Attempting protected update...');

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

          debugPrint('🔍 [OTP TRANSACTION] Fresh status: $freshStatus');

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
                bookingId +
                '_' +
                DateTime.now().millisecondsSinceEpoch.toString(),
            'systemProtected': true,
            'systemProtectedUntil': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 5)),
            ),
          });

          transactionSuccess = true;
        });

        if (!transactionSuccess) {
          debugPrint('❌ [OTP VERIFICATION] Transaction failed');
          return false;
        }

        debugPrint('✅ [OTP VERIFICATION] Transaction succeeded');

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

            debugPrint(
              '🔍 [OTP CHECK ${i + 1}] Status: $finalStatus, UpdatedBy: $lastUpdatedBy',
            );
            debugPrint(
              '🔍 [OTP CHECK ${i + 1}] TransactionId: $otpTransactionId',
            );

            if (finalStatus == 'inProgress' &&
                lastUpdatedBy == 'system_otp_verification' &&
                otpTransactionId != null) {
              debugPrint(
                '✅ [OTP VERIFICATION] Status verified and protected after ${i + 1} checks',
              );
              return true;
            } else if (finalStatus != 'inProgress') {
              debugPrint(
                '❌ [OTP VERIFICATION] Status was overwritten! Expected: inProgress, Got: $finalStatus',
              );
              debugPrint(
                '❌ [OTP VERIFICATION] This indicates another service is overwriting the status',
              );

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

              debugPrint(
                '🔄 [OTP VERIFICATION] Applied force protection update',
              );
            }
          }
        }

        debugPrint(
          '❌ [OTP VERIFICATION] Status verification failed after 10 attempts',
        );
        return false;
      } catch (updateError) {
        debugPrint('❌ [OTP VERIFICATION] Update failed: $updateError');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [OTP VERIFICATION] Fatal error: $e');
      return false;
    }
  }
}
