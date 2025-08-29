import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';

class BookingDetailForProvider extends StatefulWidget {
  final String bookingId;

  const BookingDetailForProvider({super.key, required this.bookingId});

  @override
  State<BookingDetailForProvider> createState() =>
      _BookingDetailForProviderState();
}

class _BookingDetailForProviderState extends State<BookingDetailForProvider> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Consumer<BookingProvider>(
        builder: (context, bookingProvider, child) {
          final BookingModel? currentBooking = bookingProvider.providerbookings
              .where((b) => b.id == widget.bookingId)
              .cast<BookingModel?>()
              .firstOrNull;

          if (currentBooking == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading booking details...'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Information
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.build_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Service Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.business_center,
                          'Service Name',
                          currentBooking.serviceName,
                        ),
                        _buildDetailRow(
                          Icons.monetization_on,
                          'Amount',
                          Helpers.formatCurrency(currentBooking.totalAmount),
                        ),
                        _buildDetailRow(
                          Icons.description,
                          'Description',
                          currentBooking.description.isNotEmpty
                              ? currentBooking.description
                              : 'No description provided',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              currentBooking,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentBooking.statusDisplay,
                            style: TextStyle(
                              color: _getStatusColor(currentBooking),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Customer Information Card
                if (currentBooking.status != BookingStatus.completed)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              // ✅ Privacy indicator for cancelled/paid bookings
                              if (currentBooking.status ==
                                      BookingStatus.cancelled ||
                                  currentBooking.status == BookingStatus.paid)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPrivacyIndicatorColor(
                                      currentBooking.status,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PRIVATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ✅ Customer Name - Always show
                          _buildDetailRow(
                            Icons.account_circle,
                            'Customer Name',
                            currentBooking.customerName ?? 'Loading...',
                          ),

                          // ✅ CRITICAL: Privacy Logic - Hide contact details for cancelled/paid
                          if (currentBooking.status !=
                                  BookingStatus.cancelled &&
                              currentBooking.status != BookingStatus.paid) ...[
                            // Phone if valid and present (only for non-cancelled/paid)
                            if (currentBooking.customerPhone != null &&
                                currentBooking.customerPhone!.isNotEmpty &&
                                currentBooking.customerPhone != 'No Phone')
                              _buildDetailRowWithAction(
                                Icons.phone,
                                'Phone Number',
                                currentBooking.customerPhone!,
                                onTap: () => Helpers.launchPhone(
                                  currentBooking.customerPhone!,
                                ),
                              ),

                            // Address if valid and present (only for non-cancelled/paid)
                            if ((currentBooking.customerAddressFromProfile ??
                                    '')
                                .isNotEmpty)
                              _buildDetailRow(
                                Icons.location_on,
                                'Address',
                                currentBooking.customerAddressFromProfile!,
                              ),
                          ] else ...[
                            // ✅ Privacy notice for cancelled/paid bookings
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getPrivacyNoticeColor(
                                  currentBooking.status,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getPrivacyNoticeBorderColor(
                                    currentBooking.status,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: _getPrivacyNoticeTextColor(
                                      currentBooking.status,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getPrivacyNoticeMessage(
                                        currentBooking.status,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _getPrivacyNoticeTextColor(
                                          currentBooking.status,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Booking Timeline Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timeline,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Booking Timeline',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Booked Date (replacing booking created)
                        _buildTimelineRow(
                          Icons.calendar_today,
                          'Created On',
                          Helpers.formatDateTime(currentBooking.createdAt),
                          Colors.blue,
                        ),

                        _buildTimelineRow(
                          Icons.schedule,
                          'Scheduled Date',
                          Helpers.formatDateTime(
                            currentBooking.scheduledDateTime,
                          ),
                          Colors.orange,
                        ),

                        if (currentBooking.completedAt != null)
                          _buildTimelineRow(
                            Icons.check_circle,
                            'Completed Date',
                            Helpers.formatDateTime(currentBooking.completedAt!),
                            AppColors.success,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Back Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Back to Dashboard',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper methods for privacy styling
  Color _getPrivacyIndicatorColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.paid:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getPrivacyNoticeColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return AppColors.error.withValues(alpha: 0.1);
      case BookingStatus.paid:
        return Colors.purple.withValues(alpha: 0.1);
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }

  Color _getPrivacyNoticeBorderColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return AppColors.error.withValues(alpha: 0.3);
      case BookingStatus.paid:
        return Colors.purple.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  Color _getPrivacyNoticeTextColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.paid:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPrivacyNoticeMessage(BookingStatus status) {
    switch (status) {
      case BookingStatus.cancelled:
        return 'This booking was cancelled. Customer contact details are protected for privacy.';
      case BookingStatus.paid:
        return 'Service has been paid. Customer contact details are now protected for privacy.';
      default:
        return 'Customer contact details are protected.';
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithAction(
    IconData icon,
    String label,
    String value, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookingModel booking) {
    return Helpers.getStatusColor(booking.status.toString());
  }
}
