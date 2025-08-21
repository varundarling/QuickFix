import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/core/constants/app_colors.dart';
import 'package:quickfix/core/utils/helpers.dart';
import 'package:quickfix/data/models/booking_model.dart';
import 'package:quickfix/presentation/providers/booking_provider.dart';

class BookingDetailForProvider extends StatefulWidget {
  final String bookingId; // ✅ Pass booking ID instead of booking object

  const BookingDetailForProvider({super.key, required this.bookingId});

  @override
  State<BookingDetailForProvider> createState() => _BookingDetailForProviderState();
}

class _BookingDetailForProviderState extends State<BookingDetailForProvider> {
  @override
  void initState() {
    super.initState();
  }

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
          // ✅ Find the current booking from provider's state
          final BookingModel? currentBooking =
              bookingProvider.providerbookings
                  .where((b) => b.id == widget.bookingId)
                  .isNotEmpty
              ? bookingProvider.providerbookings.firstWhere(
                  (b) => b.id == widget.bookingId,
                )
              : null;

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
                // Service Information Card
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
                          currentBooking.serviceName ?? 'Unknown Service',
                        ),
                        _buildDetailRow(
                          Icons.attach_money,
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildDetailRow(
                          Icons.account_circle,
                          'Customer Name',
                          currentBooking.customerName ?? 'Loading...',
                        ),

                        // if (currentBooking.customerPhone != null &&
                        //     currentBooking.customerPhone != 'No Phone')
                        //   _buildDetailRowWithAction(
                        //     Icons.phone,
                        //     'Phone Number',
                        //     currentBooking.customerPhone!,
                        //     onTap: () => Helpers.launchPhone(
                        //       currentBooking.customerPhone!,
                        //     ),
                        //   ),

                        // if (currentBooking.customerEmail != null &&
                        //     currentBooking.customerEmail != 'No Email')
                        //   _buildDetailRowWithAction(
                        //     Icons.email,
                        //     'Email Address',
                        //     currentBooking.customerEmail!,
                        //     onTap: () => Helpers.launchEmail(
                        //       currentBooking.customerEmail!,
                        //     ),
                        //   ),
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
                        _buildTimelineRow(
                          Icons.add_circle_outline,
                          'Booking Created',
                          Helpers.formatDateTime(currentBooking.createdAt),
                          Colors.blue,
                        ),
                        // _buildTimelineRow(
                        //   Icons.schedule,
                        //   'Scheduled Date',
                        //   Helpers.formatDateTime(
                        //     currentBooking.scheduledDateTime,
                        //   ),
                        //   Colors.orange,
                        // ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey[600],
          ), // ✅ Fixed Colors.grey to Colors.grey[1]
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors
                        .grey[600], // ✅ Fixed Colors.grey to Colors.grey[1]
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
                    color: Colors
                        .grey[600], // ✅ Fixed Colors.grey to Colors.grey[1]
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon == Icons.phone ? Icons.call : Icons.email,
                size: 16,
                color: Colors.white,
              ),
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

  Color _getStatusColor(BookingModel booking) {
    return Helpers.getStatusColor(booking.status.toString());
  }
}
