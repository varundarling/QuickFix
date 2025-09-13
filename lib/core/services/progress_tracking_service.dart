import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressTrackingService {
  static ProgressTrackingService? _instance;
  static ProgressTrackingService get instance =>
      _instance ??= ProgressTrackingService._();

  ProgressTrackingService._();

  final Map<String, Timer> _progressTimers = {};

  // ✅ Start automatic progress tracking (5% every 15 minutes, cap at 95%)
  Future<void> startProgressTracking(String bookingId) async {
    try {
      await Future.delayed(const Duration(seconds: 20));

      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        return;
      }

      final data = bookingDoc.data()!;
      final currentStatus = data['status'] as String?;

      if (currentStatus != 'inProgress') {

        return;
      }

      // Cancel existing timer if any
      _progressTimers[bookingId]?.cancel();

      // ✅ UPDATED: Start periodic progress updates (every 15 minutes)
      _progressTimers[bookingId] = Timer.periodic(
        const Duration(minutes: 15), // Changed from 30 seconds to 15 minutes
        (timer) => _updateProgress(bookingId, timer),
      );

    } catch (e) {
      // Handle errors
    }
  }

  // ✅ UPDATED: Update progress based on elapsed time (5% every 15 minutes)
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

      // ✅ NEW FORMULA: 5% increase every 15 minutes, cap at 95%
      double progress;
      final incrementsOf15Min =
          elapsed ~/ 15; // Number of complete 15-minute intervals
      progress = incrementsOf15Min * 0.05; // 5% per interval

      // ✅ Cap at 95% instead of 90%
      if (progress > 0.95) {
        progress = 0.95;
      }

      // Update progress in Firestore
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': progress,
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
          });

      
      // ✅ Stop timer if work reaches 95% cap
      if (progress >= 0.95) {
        timer.cancel();
        _progressTimers.remove(bookingId);
        
      }
    } catch (e) {
      // Handle errors
    }
  }

  // ✅ ENHANCED: Complete work and hide progress bar
  Future<void> completeWork(String bookingId) async {
    try {

      // ✅ Cancel timer immediately to stop progress updates
      _progressTimers[bookingId]?.cancel();
      _progressTimers.remove(bookingId);

      // ✅ CRITICAL: Update to completed status and remove progress tracking
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'completed',
            'workProgress': 1.0, // Set to 100% for completion
            'workEndTime': Timestamp.fromDate(DateTime.now()),
            'isWorkInProgress':
                false, // ✅ This will hide the progress bar in UI
            'completedAt': Timestamp.fromDate(DateTime.now()),
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
            'progressCompleted': true,
            'completedByProvider': true,
            'lastUpdatedBy': 'provider_completion',
            'progressTrackingActive':
                false, // ✅ Flag to indicate tracking stopped
          });

    } catch (e) {
      
      rethrow;
    }
  }

  // ✅ NEW: Set progress to specific percentage (for manual updates)
  Future<void> setProgress(String bookingId, double progress) async {
    try {
      // Ensure progress is between 0.0 and 0.95 (since we cap at 95%)
      final clampedProgress = progress.clamp(0.0, 0.95);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': clampedProgress,
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
          });

      // Handle success
    } catch (e) {
      // Handle errors
    }
  }

  // ✅ Stop progress tracking and hide progress bar
  void stopProgressTracking(String bookingId) {
    _progressTimers[bookingId]?.cancel();
    _progressTimers.remove(bookingId);
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
      // Handle errors
    }
    return null;
  }

  // ✅ Clean up all timers
  void dispose() {
    for (var timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();
  }
}
