// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/services/otp_verification_service.dart';
import 'package:quickfix/core/services/progress_tracking_service.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/data/models/rating_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';
import 'package:quickfix/core/services/otp_service.dart';
import 'package:quickfix/presentation/providers/rating_providers.dart';
import 'package:quickfix/presentation/widgets/rating/rating_display_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailForProvider extends StatefulWidget {
  final String bookingId;
  final BookingModel? booking;

  const BookingDetailForProvider({
    super.key,
    required this.bookingId,
    this.booking,
  });

  @override
  State<BookingDetailForProvider> createState() =>
      _BookingDetailForProviderState();
}

class _BookingDetailForProviderState extends State<BookingDetailForProvider> {
  bool _isUpdating = false;
  bool _showProgressCard = true;
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
                _buildDetailCard(
                  title: 'Service Details',
                  icon: Icons.build_circle,
                  children: [
                    _buildDetailRow('Service', currentBooking.serviceName),
                    _buildDetailRow(
                      'Description',
                      currentBooking.description.isNotEmpty
                          ? currentBooking.description
                          : 'No description provided',
                    ),
                    _buildDetailRow(
                      'Booked Date',
                      Helpers.formatDateTime(currentBooking.createdAt),
                    ),
                    _buildDetailRow(
                      'Scheduled Date',
                      Helpers.formatDateTime(currentBooking.scheduledDateTime),
                    ),
                    _buildDetailRow(
                      'Amount',
                      Helpers.formatCurrency(currentBooking.totalAmount),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // // Customer Information Card
                // if (currentBooking.status != BookingStatus.completed)
                //   Card(
                //     elevation: 4,
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(12),
                //     ),
                //     child: Padding(
                //       padding: const EdgeInsets.all(20),
                //       child: Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           Row(
                //             children: [
                //               Icon(
                //                 Icons.person,
                //                 color: AppColors.primary,
                //                 size: 24,
                //               ),
                //               const SizedBox(width: 12),
                //               Text(
                //                 'Customer Information',
                //                 style: TextStyle(
                //                   fontSize: 18,
                //                   fontWeight: FontWeight.bold,
                //                   color: AppColors.primary,
                //                 ),
                //               ),
                //               const Spacer(),
                //               // ✅ Privacy indicator for cancelled/paid bookings
                //               if (currentBooking.status ==
                //                       BookingStatus.cancelled ||
                //                   currentBooking.status == BookingStatus.paid)
                //                 Container(
                //                   padding: const EdgeInsets.symmetric(
                //                     horizontal: 8,
                //                     vertical: 4,
                //                   ),
                //                   decoration: BoxDecoration(
                //                     color: _getPrivacyIndicatorColor(
                //                       currentBooking.status,
                //                     ),
                //                     borderRadius: BorderRadius.circular(12),
                //                   ),
                //                   child: Row(
                //                     mainAxisSize: MainAxisSize.min,
                //                     children: [
                //                       Icon(
                //                         Icons.visibility_off,
                //                         size: 12,
                //                         color: Colors.white,
                //                       ),
                //                       const SizedBox(width: 4),
                //                       Text(
                //                         'PRIVATE',
                //                         style: TextStyle(
                //                           fontSize: 10,
                //                           fontWeight: FontWeight.bold,
                //                           color: Colors.white,
                //                         ),
                //                       ),
                //                     ],
                //                   ),
                //                 ),
                //             ],
                //           ),
                //           const SizedBox(height: 16),

                //           // ✅ Customer Name - Always show
                //           _buildDetailRowName(
                //             Icons.account_circle,
                //             'Customer Name',
                //             currentBooking.customerName ?? 'Loading...',
                //           ),

                //           // ✅ CRITICAL: Privacy Logic - Hide contact details for cancelled/paid
                //           if (currentBooking.status !=
                //                   BookingStatus.cancelled &&
                //               currentBooking.status != BookingStatus.paid) ...[
                //             // Phone if valid and present (only for non-cancelled/paid)
                //             if (currentBooking.customerPhone != null &&
                //                 currentBooking.customerPhone!.isNotEmpty &&
                //                 currentBooking.customerPhone != 'No Phone')
                //               _buildDetailRowWithCall(
                //                 Icons.phone,
                //                 'Phone Number',
                //                 currentBooking.customerPhone!,
                //               ),

                //             // Address if valid and present (only for non-cancelled/paid)
                //             if ((currentBooking.customerAddress ?? '')
                //                 .isNotEmpty)
                //               _buildDetailRowWithNavigation(
                //                 Icons.location_on,
                //                 'Service Location',
                //                 currentBooking.customerAddress!,
                //               ),
                //           ] else ...[
                //             // ✅ Privacy notice for cancelled/paid bookings
                //             const SizedBox(height: 12),
                //             Container(
                //               padding: const EdgeInsets.all(12),
                //               decoration: BoxDecoration(
                //                 color: _getPrivacyNoticeColor(
                //                   currentBooking.status,
                //                 ),
                //                 borderRadius: BorderRadius.circular(8),
                //                 border: Border.all(
                //                   color: _getPrivacyNoticeBorderColor(
                //                     currentBooking.status,
                //                   ),
                //                 ),
                //               ),
                //               child: Row(
                //                 children: [
                //                   Icon(
                //                     Icons.info_outline,
                //                     size: 16,
                //                     color: _getPrivacyNoticeTextColor(
                //                       currentBooking.status,
                //                     ),
                //                   ),
                //                   const SizedBox(width: 8),
                //                   Expanded(
                //                     child: Text(
                //                       'Customer contact details and service location are protected for privacy.',
                //                       style: TextStyle(
                //                         fontSize: 13,
                //                         color: _getPrivacyNoticeTextColor(
                //                           currentBooking.status,
                //                         ),
                //                         fontWeight: FontWeight.w500,
                //                       ),
                //                     ),
                //                   ),
                //                 ],
                //               ),
                //             ),
                //           ],
                //         ],
                //       ),
                //     ),
                //   ),
                const SizedBox(height: 16),
                _buildCustomerInfoCard(currentBooking),

                const SizedBox(height: 16),

                // Booking Timeline Card - ENHANCED
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

                        // ✅ ENHANCED Timeline with Real-time Updates
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('bookings')
                              .doc(currentBooking.id)
                              .snapshots(),
                          builder: (context, snapshot) {
                            // Use live data if available
                            Map<String, dynamic>? liveData;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              liveData =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                            }

                            final workStartTime =
                                liveData?['workStartTime'] as Timestamp?;
                            final completedAt =
                                liveData?['completedAt'] as Timestamp?;
                            final acceptedAt =
                                liveData?['acceptedAt'] as Timestamp? ??
                                (currentBooking.acceptedAt != null
                                    ? Timestamp.fromDate(
                                        currentBooking.acceptedAt!,
                                      )
                                    : null);
                            final paymentDate =
                                liveData?['paymentConfirmedAt'] as Timestamp?;
                            final currentStatus =
                                liveData?['status'] as String? ??
                                currentBooking.status.name;

                            return Column(
                              children: [
                                // 1. Created On
                                _buildTimelineRow(
                                  Icons.calendar_today,
                                  'Created On',
                                  Helpers.formatDateTime(
                                    currentBooking.createdAt,
                                  ),
                                  Colors.blue,
                                ),

                                // 2. Scheduled Date
                                _buildTimelineRow(
                                  Icons.schedule,
                                  'Scheduled Date',
                                  Helpers.formatDateTime(
                                    currentBooking.scheduledDateTime,
                                  ),
                                  Colors.orange,
                                ),

                                // 3. Accepted On (if accepted)
                                if (acceptedAt != null)
                                  _buildTimelineRow(
                                    Icons.thumb_up,
                                    'Accepted On',
                                    Helpers.formatDateTime(acceptedAt.toDate()),
                                    Colors.green,
                                  ),

                                // 4. Work Started (if started)
                                if (workStartTime != null)
                                  _buildTimelineRow(
                                    Icons.construction,
                                    'Work Started',
                                    Helpers.formatDateTime(
                                      workStartTime.toDate(),
                                    ),
                                    AppColors.primary,
                                  ),

                                // 5. Completed On (if completed)
                                if (completedAt != null)
                                  _buildTimelineRow(
                                    Icons.check_circle,
                                    'Completed On',
                                    Helpers.formatDateTime(
                                      completedAt.toDate(),
                                    ),
                                    AppColors.success,
                                  ),

                                // 6. Payment Completed (if paid)
                                if (paymentDate != null)
                                  _buildTimelineRow(
                                    Icons.payment,
                                    'Payment Completed',
                                    Helpers.formatDateTime(
                                      paymentDate.toDate(),
                                    ),
                                    Colors.purple,
                                  )
                                else if (currentStatus == 'completed')
                                  _buildTimelineRow(
                                    Icons.payment,
                                    'Payment Status',
                                    'Awaiting customer payment',
                                    Colors.orange,
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildCustomerRatingSection(currentBooking),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (currentBooking.status == BookingStatus.pending ||
                    currentBooking.status == BookingStatus.confirmed ||
                    currentBooking.status == BookingStatus.inProgress ||
                    currentBooking.status == BookingStatus.completed)
                  Column(
                    children: [
                      _buildActionButtons(), // ✅ Use the method here
                      const SizedBox(height: 16),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ FIXED: Customer Information Card with proper privacy logic
  Widget _buildCustomerInfoCard(BookingModel booking) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: AppColors.primary, size: 24),
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
                // ✅ FIXED: Show privacy indicator only for cancelled/paid/refunded
                if (booking.status == BookingStatus.cancelled ||
                    booking.status == BookingStatus.paid ||
                    booking.status == BookingStatus.refunded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPrivacyIndicatorColor(booking.status),
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

            // ✅ Customer Name - Always show (never private)
            _buildDetailRowName(
              Icons.account_circle,
              'Customer Name',
              booking.customerName ?? 'Loading customer...',
            ),

            // ✅ CRITICAL FIX: Show contact details for ALL active booking statuses
            if (booking.status == BookingStatus.pending ||
                booking.status == BookingStatus.confirmed ||
                booking.status == BookingStatus.inProgress ||
                booking.status == BookingStatus.completed) ...[
              // Phone number with call button
              if (booking.customerPhone != null &&
                  booking.customerPhone!.isNotEmpty &&
                  booking.customerPhone != 'No Phone')
                _buildDetailRowWithCall(
                  Icons.phone,
                  'Phone Number',
                  booking.customerPhone!,
                ),

              // // Email if available
              // if (booking.customerEmail != null &&
              //     booking.customerEmail!.isNotEmpty &&
              //     booking.customerEmail != 'No Email')
              //   _buildDetailRowName(
              //     Icons.email,
              //     'Email',
              //     booking.customerEmail!,
              //   ),

              // Service location
              if (booking.customerAddress?.isNotEmpty == true)
                _buildDetailRowWithNavigation(
                  Icons.location_on,
                  'Service Location',
                  booking.customerAddress!,
                ),
            ] else ...[
              // ✅ Privacy notice for finished bookings only
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getPrivacyNoticeColor(booking.status),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getPrivacyNoticeBorderColor(booking.status),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: _getPrivacyNoticeTextColor(booking.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer contact details are now protected for privacy.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _getPrivacyNoticeTextColor(booking.status),
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
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Phone number row with call icon
  Widget _buildDetailRowWithCall(
    IconData icon,
    String label,
    String phoneNumber,
  ) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _launchCaller(phoneNumber),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.call,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Launch caller method
  Future<void> _launchCaller(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch phone dialer'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ✅ NEW: Address row with navigation button
  Widget _buildDetailRowWithNavigation(
    IconData icon,
    String label,
    String address,
  ) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _launchMaps(address),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Launch maps method
  Future<void> _launchMaps(String address) async {
    try {
      final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );

      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open maps'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

  Widget _buildDetailRowName(IconData icon, String label, String value) {
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

  Future<void> _handleAcceptBooking() async {
    setState(() => _isUpdating = true);

    try {
      final bookingProvider = context.read<BookingProvider>();

      // ✅ Get booking from provider (same source as card)
      final currentBooking = bookingProvider.providerbookings
          .where((b) => b.id == widget.bookingId)
          .firstOrNull;

      if (currentBooking == null) {
        throw Exception('Booking not found in provider');
      }

      // debugPrint('🔄 [DETAIL] Accepting booking: ${widget.bookingId}');
      // debugPrint('🔄 [DETAIL] Provider ID: ${currentBooking.providerId}');

      // Now use currentBooking which is guaranteed to exist
      final success = await bookingProvider.updateBookingStatus(
        widget.bookingId,
        BookingStatus.confirmed,
        currentBooking.providerId, // ✅ Safe to use
      );

      if (success && mounted) {
        // Generate OTP
        try {
          await OTPService.instance.createOTPForBooking(widget.bookingId);
          //debugPrint('✅ [DETAIL] OTP generated');
        } catch (otpError) {
          //debugPrint('⚠️ [DETAIL] OTP generation failed: $otpError');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Booking accepted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        throw Exception('Failed to update booking status');
      }
    } catch (e) {
      //debugPrint('❌ [DETAIL] Error accepting booking: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _handleRejectBooking() async {
    setState(() => _isUpdating = true);

    try {
      final bookingProvider = context.read<BookingProvider>();

      // Update booking to cancelled status
      final success = await bookingProvider.updateBookingStatus(
        widget.bookingId,
        BookingStatus.cancelled,
        widget.booking?.providerId ?? '',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Booking has been rejected.'),
            backgroundColor: AppColors.error,
          ),
        );

        // Navigate back to dashboard
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _buildActionButtons() {
    return Consumer<BookingProvider>(
      builder: (context, bookingProvider, child) {
        final BookingModel? currentBooking = bookingProvider.providerbookings
            .where((b) => b.id == widget.bookingId)
            .cast<BookingModel?>()
            .firstOrNull;

        if (currentBooking == null) return const SizedBox.shrink();

        switch (currentBooking.status) {
          case BookingStatus.pending:
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _handleAcceptBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 24),
                    label: Text(
                      _isUpdating ? 'Processing...' : 'Accept Booking',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating ? null : _handleRejectBooking,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Reject Booking'),
                  ),
                ),
              ],
            );

          case BookingStatus.confirmed:
            // ✅ FIXED: Check both booking status AND OTP verification status
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('booking_otps')
                  .doc(currentBooking.id)
                  .snapshots(),
              builder: (context, otpSnapshot) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(currentBooking.id)
                      .snapshots(),
                  builder: (context, bookingSnapshot) {
                    // Check if OTP is verified or work is already in progress
                    bool isOtpVerified = false;
                    bool isWorkInProgress = false;

                    if (otpSnapshot.hasData && otpSnapshot.data!.exists) {
                      final otpData =
                          otpSnapshot.data!.data() as Map<String, dynamic>?;
                      isOtpVerified = otpData?['isVerified'] as bool? ?? false;
                    }

                    if (bookingSnapshot.hasData &&
                        bookingSnapshot.data!.exists) {
                      final bookingData =
                          bookingSnapshot.data!.data() as Map<String, dynamic>?;
                      isWorkInProgress =
                          bookingData?['isWorkInProgress'] as bool? ?? false;
                      final status = bookingData?['status'] as String?;

                      // If status is already inProgress, show progress card instead
                      if (status == 'inProgress') {
                        return _buildWorkProgressCard(currentBooking);
                      }
                    }

                    // ✅ If OTP is already verified or work is in progress, show appropriate message
                    if (isOtpVerified || isWorkInProgress) {
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withValues(alpha: 0.1),
                                Colors.green.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Work Already Started!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Customer verification completed. Work is in progress.',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // ✅ Show OTP entry only if not verified and not in progress
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withValues(alpha: 0.1),
                              Colors.orange.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Ready to Start!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ask customer for their 4-digit personal code to begin work.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          OTPVerificationScreen(
                                            booking: currentBooking,
                                          ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  'Enter Customer Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );

          case BookingStatus.inProgress:
            return _buildWorkProgressCard(currentBooking);

          case BookingStatus.completed:
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Work Completed!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Waiting for customer payment confirmation.',
                    style: TextStyle(color: AppColors.success, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildWorkProgressCard(BookingModel booking) {
    if (!_showProgressCard) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isWorkInProgress = (data['isWorkInProgress'] as bool?) ?? false;
        final ts = data['workStartTime'] as Timestamp?;
        final workStartTime = ts?.toDate();
        final dbProgress = ((data['workProgress'] ?? 0.0) as num).toDouble();

        if (!isWorkInProgress || workStartTime == null) {
          return const SizedBox.shrink();
        }

        final display = _computeSyncedProgress(workStartTime, dbProgress);
        final elapsed = DateTime.now().difference(workStartTime);
        final elapsedHours = elapsed.inHours;
        final remainingMinutes = elapsed.inMinutes % 60;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.work,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work in Progress',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(display * 100).round()}% Complete',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        elapsedHours > 0
                            ? '${elapsedHours}h ${remainingMinutes}m'
                            : '${elapsed.inMinutes}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: display,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleCompleteWork,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'Complete Work',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _computeSyncedProgress(DateTime workStartTime, double dbProgress) {
    final minutes = DateTime.now().difference(workStartTime).inMinutes;
    final intervals = minutes ~/ 15; // step every 15 minutes
    final stepped = 0.10 + (intervals * 0.05); // base 10% + 5% per step
    final computed = stepped.clamp(0.0, 0.95);
    // Never regress below the server value, never exceed 95%
    return (dbProgress.isNaN ? 0.0 : dbProgress).clamp(0.0, 0.95) > computed
        ? dbProgress.clamp(0.0, 0.95)
        : computed;
  }

  Future<void> _handleCompleteWork() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Complete Work'),
          ],
        ),
        content: const Text(
          'Are you sure you want to mark this work as completed?\n\n'
          'This will move the booking to completed status and the customer can proceed with payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Complete Work'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // ✅ First hide the progress card immediately
        setState(() {
          _showProgressCard = false;
        });

        // ✅ Then complete the work
        await ProgressTrackingService.instance.completeWork(widget.bookingId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Work completed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );

          // Navigate back after a short delay to show the success message
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        // ✅ If error occurs, show progress card again
        setState(() {
          _showProgressCard = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error completing work: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildCustomerRatingSection(BookingModel booking) {
    // Only show rating section for paid bookings
    if (booking.status != BookingStatus.paid) {
      return const SizedBox.shrink();
    }

    return Consumer<RatingProvider>(
      builder: (context, ratingProvider, child) {
        return FutureBuilder<RatingModel?>(
          future: ratingProvider.getRatingForBooking(booking.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final rating = snapshot.data;

            if (rating != null) {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  RatingDisplayWidget(rating: rating),
                ],
              );
            } else {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star_border, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Customer hasn\'t rated this service yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }
}
