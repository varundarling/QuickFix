// lib/core/services/payment_service.dart
// Production-ready payment recording and retrieval with idempotency.
// Writes actual paid amount under bookings/{bookingId}/payments/{paymentId}.
// Never writes any commission values; splitting is handled by Cloud Functions.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentResult {
  final String bookingId;
  final String paymentId;
  final double actualPaidAmount;
  final String currency;
  final String method; // e.g., 'upi', 'card', 'wallet', 'cash'
  final String status; // 'success' | 'failed' | 'pending'
  final DateTime createdAt;

  PaymentResult({
    required this.bookingId,
    required this.paymentId,
    required this.actualPaidAmount,
    required this.currency,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  factory PaymentResult.fromMap(
    String bookingId,
    String paymentId,
    Map<String, dynamic> data,
  ) {
    final numAmount = data['amount'] is num ? data['amount'] as num : 0;
    final ts = data['createdAt'];
    DateTime created = DateTime.now();
    if (ts is Timestamp) created = ts.toDate();

    return PaymentResult(
      bookingId: bookingId,
      paymentId: paymentId,
      actualPaidAmount: (numAmount).toDouble(),
      currency: (data['currency']?.toString().isNotEmpty ?? false)
          ? data['currency'].toString()
          : 'INR',
      method: data['method']?.toString() ?? 'unknown',
      status: data['status']?.toString() ?? 'success',
      createdAt: created,
    );
  }
}

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Create or upsert a successful payment document for a booking, idempotently.
  // - If paymentId exists with status=success, returns the stored document (no-op).
  // - If it exists with different amount/status, it will not overwrite success records.
  // - If not present, creates it with server timestamp.
  Future<PaymentResult> recordSuccessfulPayment({
    required String bookingId,
    required double actualPaidAmount,
    String currency = 'INR',
    required String method,
    required String
    paymentId, // Pass gateway payment_id; required for idempotency
    Map<String, dynamic>? gatewayMeta,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }
    if (actualPaidAmount.isNaN ||
        !actualPaidAmount.isFinite ||
        actualPaidAmount <= 0) {
      throw ArgumentError('Invalid actualPaidAmount');
    }
    if (bookingId.isEmpty || paymentId.isEmpty) {
      throw ArgumentError('bookingId and paymentId are required');
    }

    final ref = _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('payments')
        .doc(paymentId);

    return await _firestore.runTransaction<PaymentResult>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        // If already success, return as-is (idempotent).
        if ((data['status']?.toString() ?? '') == 'success') {
          return PaymentResult.fromMap(bookingId, paymentId, data);
        }
        // If previously failed/pending, upgrade to success with same paymentId.
        tx.update(ref, {
          'amount': double.parse(actualPaidAmount.toStringAsFixed(2)),
          'currency': currency,
          'method': method,
          'status': 'success',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
          if (gatewayMeta != null) 'gatewayMeta': gatewayMeta,
        });
        final updated = Map<String, dynamic>.from(data)
          ..['amount'] = double.parse(actualPaidAmount.toStringAsFixed(2))
          ..['currency'] = currency
          ..['method'] = method
          ..['status'] = 'success';
        return PaymentResult.fromMap(bookingId, paymentId, updated);
      } else {
        tx.set(ref, {
          'amount': double.parse(actualPaidAmount.toStringAsFixed(2)),
          'currency': currency,
          'method': method,
          'status': 'success',
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'bookingId': bookingId,
          'paymentId': paymentId,
          if (gatewayMeta != null) 'gatewayMeta': gatewayMeta,
        }, SetOptions(merge: false));
        // Return optimistic result; createdAt will be server time.
        return PaymentResult(
          bookingId: bookingId,
          paymentId: paymentId,
          actualPaidAmount: double.parse(actualPaidAmount.toStringAsFixed(2)),
          currency: currency,
          method: method,
          status: 'success',
          createdAt: DateTime.now(),
        );
      }
    });
  }

  // Fetch the latest successful payment for display of actual paid amount.
  Future<PaymentResult?> getLatestSuccessfulPayment(String bookingId) async {
    final qs = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .collection('payments')
        .where('status', isEqualTo: 'success')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;
    final d = qs.docs.first;
    return PaymentResult.fromMap(bookingId, d.id, d.data());
  }
}
