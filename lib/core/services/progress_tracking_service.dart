import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressTrackingService {
  static ProgressTrackingService? _instance;
  static ProgressTrackingService get instance =>
      _instance ??= ProgressTrackingService._();

  ProgressTrackingService._();

  final Map<String, Timer> _progressTimers = {};

  // Compute display progress from start time with 5% every 15 minutes, base 10%, cap 95%
  // This is the single formula used everywhere for consistency.
  double computeProgressFromStart(DateTime workStartTime, double dbProgress) {
    final elapsed = DateTime.now().difference(workStartTime).inMinutes;
    final intervals = elapsed ~/ 15; // number of complete 15-minute intervals
    // Base 10% after OTP verification + 5% per 15 minutes, cap at 95%
    final computed = math.min(0.95, 0.10 + (intervals * 0.05));
    // Always respect the greater of persisted and computed to avoid regressions
    return math.max(dbProgress, computed);
  }

  Future<void> startProgressTracking(String bookingId) async {
    try {
      // Cancel previous timer if any before starting a new one
      _progressTimers[bookingId]?.cancel();

      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!doc.exists) {
        return;
      }

      final data = doc.data()!;
      final status = (data['status'] as String?)?.toLowerCase();
      final isInProgress =
          status == 'inprogress' ||
          status == 'in_progress' ||
          status == 'in-progress';
      final ts = data['workStartTime'] as Timestamp?;
      final workStartTime = ts?.toDate();
      final dbProgress = ((data['workProgress'] ?? 0.0) as num).toDouble();

      if (!isInProgress || workStartTime == null) {
        // Not in a state to track progress
        return;
      }

      // Mark tracking flag on for clarity (non-blocking)
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set({'progressTrackingActive': true}, SetOptions(merge: true));

      // Immediate sync write to avoid “stuck at 10%” perception while waiting 15 minutes
      final initial = computeProgressFromStart(workStartTime, dbProgress);
      if (initial > dbProgress + 1e-6) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
              'workProgress': initial,
              'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
            });
      }

      // Periodic update every 15 minutes to persist computed progress
      _progressTimers[bookingId] = Timer.periodic(const Duration(minutes: 15), (
        timer,
      ) async {
        try {
          final fresh = await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();
          if (!fresh.exists) {
            timer.cancel();
            _progressTimers.remove(bookingId);
            return;
          }

          final d = fresh.data()!;
          final st = (d['status'] as String?)?.toLowerCase();
          final inProg =
              st == 'inprogress' || st == 'in_progress' || st == 'in-progress';
          final ts2 = d['workStartTime'] as Timestamp?;
          final start2 = ts2?.toDate();
          final currentDb = ((d['workProgress'] ?? 0.0) as num).toDouble();

          if (!inProg || start2 == null) {
            timer.cancel();
            _progressTimers.remove(bookingId);
            return;
          }

          final newProgress = computeProgressFromStart(start2, currentDb);

          // Stop at 95% and keep rendering 95% until completion
          if (newProgress >= 0.95 - 1e-6) {
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .update({
                  'workProgress': 0.95,
                  'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
                });

            // No need to cancel; we keep the bar at 95% until completion, but to save writes, stop timer
            timer.cancel();
            _progressTimers.remove(bookingId);
            return;
          }

          if (newProgress > currentDb + 1e-6) {
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .update({
                  'workProgress': newProgress,
                  'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
                });
          }
        } catch (_) {
          // On error, do nothing; next tick will retry
        }
      });
    } catch (_) {
      // Ignore; UI computes display progress too
    }
  }

  // Complete work: set status completed, set to 100%, and hide progress in UI
  Future<void> completeWork(String bookingId) async {
    try {
      _progressTimers[bookingId]?.cancel();
      _progressTimers.remove(bookingId);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'completed',
            'workProgress': 1.0,
            'workEndTime': Timestamp.fromDate(DateTime.now()),
            'isWorkInProgress': false,
            'completedAt': Timestamp.fromDate(DateTime.now()),
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
            'progressCompleted': true,
            'completedByProvider': true,
            'lastUpdatedBy': 'provider_completion',
            'progressTrackingActive': false,
          });
    } catch (e) {
      rethrow;
    }
  }

  // Optional manual set with clamp to 95%
  Future<void> setProgress(String bookingId, double progress) async {
    try {
      final clamped = progress.clamp(0.0, 0.95);
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'workProgress': clamped,
            'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
          });
    } catch (_) {}
  }

  void stopProgressTracking(String bookingId) {
    _progressTimers[bookingId]?.cancel();
    _progressTimers.remove(bookingId);
  }

  bool isTrackingProgress(String bookingId) =>
      _progressTimers.containsKey(bookingId);

  Future<double?> getCurrentProgress(String bookingId) async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) return null;
      final data = bookingDoc.data()!;
      return ((data['workProgress'] ?? 0.0) as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    for (var t in _progressTimers.values) {
      t.cancel();
    }
    _progressTimers.clear();
  }
}
