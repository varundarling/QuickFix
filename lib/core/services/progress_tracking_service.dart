// lib/core/services/progress_tracking_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProgressTrackingService {
  static ProgressTrackingService? _instance;
  static ProgressTrackingService get instance =>
      _instance ??= ProgressTrackingService._();

  ProgressTrackingService._();

  final Map<String, Timer> _progressTimers = {};

  // ✅ Start automatic progress tracking (30+ minutes to reach 75%)
  Future<void> startProgressTracking(String bookingId) async {
    try {
      debugPrint('📈 Starting progress tracking for: $bookingId');

      await Future.delayed(const Duration(seconds: 20));

      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        debugPrint('❌ Booking not found, cancelling progress tracking');
        return;
      }

      final data = bookingDoc.data()!;
      final currentStatus = data['status'] as String?;

      if (currentStatus != 'inProgress') {
        debugPrint(
          '❌ Booking no longer inProgress ($currentStatus), cancelling progress tracking',
        );
        return;
      }

      // Cancel existing timer if any
      _progressTimers[bookingId]?.cancel();

      // Start periodic progress updates (every 30 seconds)
      _progressTimers[bookingId] = Timer.periodic(
        const Duration(seconds: 30),
        (timer) => _updateProgress(bookingId, timer),
      );
      debugPrint('✅ Progress tracking started successfully for: $bookingId');
    } catch (e) {
      debugPrint('❌ Error starting progress tracking: $e');
    }
  }

  // ✅ Update progress based on elapsed time
  Future<void> _updateProgress(String bookingId, Timer timer) async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        timer.cancel();
        _progressTimers.remove(bookingId);
        return;
      }

      final data = bookingDoc.data()!;
      final workStartTime = (data['workStartTime'] as Timestamp?)?.toDate();
      final currentStatus = data['status'] as String?;

      if (workStartTime == null || currentStatus != 'inProgress') {
        timer.cancel();
        _progressTimers.remove(bookingId);
        return;
      }

      // Calculate progress based on elapsed time
      final elapsed = DateTime.now().difference(workStartTime).inMinutes;

      // Progress formula: 75% in 30 minutes, then slower to 90% in 45 minutes
      double progress;
      if (elapsed <= 30) {
        // 0% to 75% in first 30 minutes
        progress = (elapsed / 30.0) * 0.75;
      } else if (elapsed <= 45) {
        // 75% to 90% in next 15 minutes
        final extraMinutes = elapsed - 30;
        progress = 0.75 + (extraMinutes / 15.0) * 0.15;
      } else {
        // Cap at 90% until manually completed
        progress = 0.90;
      }

      // Update progress in Firestore
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': progress,
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
          });

      debugPrint(
        '📈 Progress updated for $bookingId: ${(progress * 100).toInt()}%',
      );

      // Stop timer if work is completed or cancelled
      if (progress >= 0.90) {
        timer.cancel();
        _progressTimers.remove(bookingId);
      }
    } catch (e) {
      debugPrint('❌ Error updating progress: $e');
    }
  }

  // ✅ ENHANCED: Manually complete work (set to 100%) - Called when provider clicks "Work Completed"
  Future<void> completeWork(String bookingId) async {
    try {
      debugPrint(
        '🎯 [COMPLETE WORK] Provider clicked Work Completed for: $bookingId',
      );

      // Cancel timer immediately
      _progressTimers[bookingId]?.cancel();
      _progressTimers.remove(bookingId);

      debugPrint(
        '🔄 [COMPLETE WORK] Setting progress to 100% and status to completed',
      );

      // ✅ CRITICAL: Update to completed status with 100% progress
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'completed',
            'workProgress': 1.0, // ✅ SET TO 100%
            'workEndTime': Timestamp.fromDate(DateTime.now()),
            'isWorkInProgress': false,
            'completedAt': Timestamp.fromDate(DateTime.now()),
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
            'progressCompleted': true, // ✅ Mark progress as manually completed
            'completedByProvider': true, // ✅ Indicate provider completed it
            'lastUpdatedBy': 'provider_completion', // ✅ Track who updated it
          });

      debugPrint(
        '✅ [COMPLETE WORK] Work completed with 100% progress for booking: $bookingId',
      );
      debugPrint(
        '✅ [COMPLETE WORK] Status changed to completed, progress bar now shows 100%',
      );
    } catch (e) {
      debugPrint('❌ [COMPLETE WORK] Error completing work: $e');
      rethrow; // Re-throw so calling code can handle the error
    }
  }

  // ✅ NEW: Set progress to specific percentage (for manual updates)
  Future<void> setProgress(String bookingId, double progress) async {
    try {
      // Ensure progress is between 0.0 and 1.0
      final clampedProgress = progress.clamp(0.0, 1.0);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': clampedProgress,
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
          });

      debugPrint(
        '📈 Progress manually set to ${(clampedProgress * 100).toInt()}% for booking: $bookingId',
      );
    } catch (e) {
      debugPrint('❌ Error setting progress: $e');
    }
  }

  // ✅ Stop progress tracking
  void stopProgressTracking(String bookingId) {
    _progressTimers[bookingId]?.cancel();
    _progressTimers.remove(bookingId);
    debugPrint('🛑 Progress tracking stopped for: $bookingId');
  }

  // ✅ Check if progress tracking is active for a booking
  bool isTrackingProgress(String bookingId) {
    return _progressTimers.containsKey(bookingId);
  }

  // ✅ Get current progress for a booking
  Future<double?> getCurrentProgress(String bookingId) async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data()!;
        return (data['workProgress'] as num?)?.toDouble();
      }
    } catch (e) {
      debugPrint('❌ Error getting current progress: $e');
    }
    return null;
  }

  // ✅ Clean up all timers
  void dispose() {
    for (var timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();
    debugPrint('🧹 All progress tracking timers disposed');
  }
}
