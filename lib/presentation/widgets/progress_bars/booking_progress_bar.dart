import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/core/constants/app_colors.dart';

class BookingProgressBar extends StatefulWidget {
  final String bookingId;
  final double height;
  final bool showPercentText;

  const BookingProgressBar({
    super.key,
    required this.bookingId,
    this.height = 10,
    this.showPercentText = true,
  });

  @override
  State<BookingProgressBar> createState() => _BookingProgressBarState();
}

class _BookingProgressBarState extends State<BookingProgressBar> {
  Timer? _uiTick;

  @override
  void initState() {
    super.initState();
    // Re-render each minute so UI shows the computed step right at 15-minute boundaries
    _uiTick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTick?.cancel();
    super.dispose();
  }

  double _computeDisplay(BookingModel b) {
    // If not in progress, hide via caller; return 0 to avoid showing movement
    if (b.status != BookingStatus.inProgress || b.workStartTime == null) {
      return 0.0;
    }
    final db = b.workProgress;
    final minutes = DateTime.now().difference(b.workStartTime!).inMinutes;
    final intervals = minutes ~/ 15; // 5% each 15 min
    final computed = math.min(0.95, 0.10 + intervals * 0.05);
    return math.max(db, computed); // never regress below DB value
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();

        final doc = snap.data!;
        final booking = BookingModel.fromFireStore(doc);
        final isInProgress = booking.status == BookingStatus.inProgress;
        final shouldHide =
            !isInProgress ||
            !booking.isWorkInProgress ||
            booking.workStartTime == null;

        if (shouldHide) return const SizedBox.shrink();

        final progress = _computeDisplay(booking).clamp(0.0, 0.95);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: widget.height,
                backgroundColor: Colors.grey.shade300,
                color: AppColors.primary,
              ),
            ),
            if (widget.showPercentText) ...[
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% • In progress',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );
      },
    );
  }
}
